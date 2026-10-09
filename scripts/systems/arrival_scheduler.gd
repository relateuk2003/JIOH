# scripts/systems/arrival_scheduler.gd — JIOH-28: who turns up when.
#
# A morning is a pure function of the campaign seed, the day, the roster and
# the relationships as they stood when the day began (snapshotted into the
# day record the first time the day is looked at). build_day_schedule()
# has no side effects and draws only from RNGs seeded per trade per day, so a
# morning the player missed replays to exactly the morning they would have
# watched. Times are unix stamps from WorldClock, never frame counts.
#
# A world system, not an autoload: it lives in the office level and dies with
# it. The live path is driven by WorldClock.minute_elapsed.
class_name ArrivalScheduler
extends Node

signal arrival_due(slot: ArrivalSlot)
signal schedule_built(campaign_day: int, slots: Array[ArrivalSlot])
signal no_show(trade_id: StringName, campaign_day: int)

const GOLDEN := 2654435761
## Earliest a lets-self-in trade can be on site, minutes before Handout.
const EARLIEST_SELF_IN := 60.0

var roster: TradeRoster
var today: int = 0
var slots: Array[ArrivalSlot] = []


func _ready() -> void:
	roster = TradeRoster.shipped()
	WorldClock.minute_elapsed.connect(_on_minute)
	WorldClock.day_rolled.connect(func(_d): _begin_today())
	CampaignState.campaign_started.connect(_begin_today)
	_begin_today()


## Arrivals for a campaign day, in arrival order. Pure: the same inputs give
## the same slots however often it is called. No-shows (drifted past 10:00)
## are left out; no_shows_for() lists them.
func build_day_schedule(campaign_day: int) -> Array[ArrivalSlot]:
	return _plan(campaign_day).slots


func no_shows_for(campaign_day: int) -> Array[StringName]:
	return _plan(campaign_day).no_shows


## Replays days the player was absent for, oldest first, through the same
## outcomes the live path uses. Nobody was at the hatch, so every arrival runs
## out of patience.
func replay_missed_days(from_day: int, to_day: int) -> void:
	for day in range(maxi(from_day, 1), to_day + 1):
		if HatchOutcomes.is_settled(day):
			continue
		_open_day(day)
		var plan := _plan(day)
		for id in plan.no_shows:
			_record_no_show(id, day)
		for slot in plan.slots:
			_expire(slot, day)
		HatchOutcomes.settle(day)


# --- Live path --------------------------------------------------------------

func _begin_today() -> void:
	today = WorldClock.get_campaign_day()
	if today < 1:
		slots = []
		return
	replay_missed_days(1, mini(today - 1, CampaignState.CAMPAIGN_LENGTH))
	if today > CampaignState.CAMPAIGN_LENGTH:
		slots = []
		return
	_open_day(today)
	var plan := _plan(today)
	slots = plan.slots
	schedule_built.emit(today, slots)
	for id in plan.no_shows:
		if HatchOutcomes.status(id, today) == "":
			_record_no_show(id, today)
	_check(WorldClock.now_unix())


func _on_minute() -> void:
	if WorldClock.get_campaign_day() != today:
		return  # day_rolled will rebuild
	_check(WorldClock.now_unix())


## Arrivals whose time has come are announced once; arrivals whose patience
## has run out unserved are resolved, even if they arrived while the game was
## shut (the player never sees those).
func _check(now: int) -> void:
	var pending := 0
	for slot in slots:
		var st := HatchOutcomes.status(slot.trade_id, today)
		if st in ["served", "no_handout"]:
			continue
		if now >= slot.patience_expiry_unix:
			_expire(slot, today)
		elif now >= slot.arrival_unix:
			if st == "":
				HatchOutcomes.mark(slot.trade_id, today, "arrived")
				arrival_due.emit(slot)
			pending += 1
		else:
			pending += 1
	if pending == 0 and not slots.is_empty() and not HatchOutcomes.is_settled(today):
		HatchOutcomes.settle(today)


## Handout (JIOH-30) calls this when a pack has gone across the hatch, so the
## trade's patience no longer runs.
func mark_served(trade_id: StringName) -> void:
	HatchOutcomes.mark(trade_id, today, "served")


func _expire(slot: ArrivalSlot, day: int) -> void:
	if HatchOutcomes.status(slot.trade_id, day) in ["served", "no_handout"]:
		return
	HatchOutcomes.no_handout(slot.trade_id, day)


func _record_no_show(id: StringName, day: int) -> void:
	HatchOutcomes.no_show(id, day)
	no_show.emit(id, day)


# --- The pure part ----------------------------------------------------------

func _plan(campaign_day: int) -> Dictionary:
	var out: Array[ArrivalSlot] = []
	var missing: Array[StringName] = []
	var day := CampaignState.get_day(campaign_day)
	if day == null:
		return {"slots": out, "no_shows": missing}
	var saturday := WorldClock.weekday_of(day.epoch_day) == 6
	var booked := {}
	for job in InformationBoard.live_jobs_on(campaign_day):
		booked[job.trade] = true
	for id in day.scheduled_trades:
		booked[id] = true
	var handout_utc := WorldClock.utc_of_local_midnight(day.epoch_day) + DayPhase.schedule.handout_minute * 60
	var order := {}
	for t in roster.trades:
		order[t.trade_id] = order.size()
		if not (day.is_working_day or (saturday and t.works_saturdays)):
			continue
		if not (booked.has(t.trade_id) or t.regular):
			continue
		var standing := _opening_standing(t.trade_id, campaign_day)
		if standing.walked:
			continue
		var minutes := arrival_offset_minutes(t, campaign_day, standing.strikes)
		if minutes > PunctualityProfile.HANDOUT_MINUTES:
			missing.append(t.trade_id)
			continue
		var slot := ArrivalSlot.new()
		slot.trade_id = t.trade_id
		slot.arrival_unix = handout_utc + roundi(minutes * 60.0)
		slot.patience_expiry_unix = slot.arrival_unix + roundi(t.patience_seconds)
		slot.expected = booked.has(t.trade_id) or t.regular
		out.append(slot)
	out.sort_custom(func(a, b): return a.arrival_unix < b.arrival_unix \
		or (a.arrival_unix == b.arrival_unix and order[a.trade_id] < order[b.trade_id]))
	return {"slots": out, "no_shows": missing}


## Minutes after 07:30. Habit sits mid-window; the day's draw scatters it by
## the variance and the window clamps it. Strikes then push it later, after
## the clamp, so a trade you have burned can drift right out of the morning.
func arrival_offset_minutes(t: TradespersonData, campaign_day: int, strikes: int) -> float:
	var p := t.punctuality
	var rng := day_rng(t.trade_id, campaign_day)
	var habit := (p.window_start_minutes + p.window_end_minutes) * 0.5
	var sample := clampf(habit + rng.randfn(0.0, p.variance_minutes), p.window_start_minutes, p.window_end_minutes)
	sample += p.drift_per_campaign_day * strikes
	var floor_min := -EARLIEST_SELF_IN if p.lets_self_in else 0.0
	return maxf(sample, floor_min)


## Relationships as they stood when the day began. A strike earned at 07:40
## must not move the 09:00 arrival, nor a relaunch at 08:00 reshuffle the
## morning, so the first look at a day writes this snapshot into its record.
func _opening_standing(trade_id: StringName, campaign_day: int) -> Dictionary:
	var rec := CampaignState.day_records[campaign_day - 1] if campaign_day <= CampaignState.day_records.size() else {}
	var snap: Dictionary = rec.get("opening_standing", {})
	if snap.has(String(trade_id)):
		return snap[String(trade_id)]
	var r := CampaignState.get_relationship(trade_id)
	return {"strikes": r.strikes, "walked": r.has_walked}


func _open_day(campaign_day: int) -> void:
	if campaign_day < 1 or campaign_day > CampaignState.day_records.size():
		return
	var rec: Dictionary = CampaignState.day_records[campaign_day - 1]
	if rec.has("opening_standing"):
		return
	var snap := {}
	for t in roster.trades:
		var r := CampaignState.get_relationship(t.trade_id)
		snap[String(t.trade_id)] = {"strikes": r.strikes, "walked": r.has_walked}
	rec["opening_standing"] = snap
	CampaignState.commit(&"day_opened")


## The per-trade, per-day generator. Handout's read jitter (JIOH-30) draws
## from the same seed.
static func day_rng(trade_id: StringName, campaign_day: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(CampaignState.campaign_seed) ^ hash(trade_id) ^ (campaign_day * GOLDEN)
	return rng
