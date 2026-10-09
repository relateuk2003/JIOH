# autoload/campaign_state.gd — JIOH-15: the fortnight laid over the player's
# real calendar.
#
# New Game stamps today's date and generates fourteen consecutive days from
# it, flagged working or weekend by weekday. The campaign day is always a date
# difference from the stamp, never a stored counter, so it cannot drift.
extends Node

signal campaign_started

const CAMPAIGN_LENGTH := 14

var campaign_start_utc: int = 0
## Local epoch day of the stamp. Kept alongside the UTC instant so a later
## timezone change does not move day 1.
var campaign_start_epoch_day: int = 0
var campaign_days: Array[CampaignDay] = []


func has_campaign() -> bool:
	return campaign_start_utc != 0


## Stamps a new campaign at the current WorldClock time.
func new_campaign() -> void:
	campaign_start_utc = WorldClock.now_unix()
	campaign_start_epoch_day = WorldClock.local_epoch_day(campaign_start_utc)
	generate_calendar(campaign_start_epoch_day)
	campaign_started.emit()


func clear() -> void:
	campaign_start_utc = 0
	campaign_start_epoch_day = 0
	campaign_days.clear()


## Fourteen consecutive dates from start_epoch_day. Bank holidays are ignored
## on purpose: the office does not observe them.
func generate_calendar(start_epoch_day: int) -> void:
	campaign_days.clear()
	var ordinal := 0
	for i in CAMPAIGN_LENGTH:
		var day := CampaignDay.new()
		day.index = i + 1
		day.epoch_day = start_epoch_day + i
		day.date = WorldClock.date_string(day.epoch_day)
		var weekday := WorldClock.weekday_of(day.epoch_day)
		day.is_working_day = weekday != 0 and weekday != 6
		if day.is_working_day:
			ordinal += 1
			day.working_day_ordinal = ordinal
		campaign_days.append(day)


## Campaign day at a UTC instant: 0 before the start (or with no campaign),
## 1..14 during, and above 14 once the fortnight has concluded.
func campaign_day_for(utc: int) -> int:
	if not has_campaign():
		return 0
	var d := WorldClock.local_epoch_day(utc) - campaign_start_epoch_day + 1
	return d if d >= 1 else 0


func get_day(index: int) -> CampaignDay:
	if index < 1 or index > campaign_days.size():
		return null
	return campaign_days[index - 1]


func is_working_day_at(utc: int) -> bool:
	var day := get_day(campaign_day_for(utc))
	return day != null and day.is_working_day


func is_concluded() -> bool:
	return has_campaign() and WorldClock.get_campaign_day() > CAMPAIGN_LENGTH


## The calendar day carrying a working-day ordinal (1..10), or null.
func day_for_working_ordinal(ordinal: int) -> CampaignDay:
	for day in campaign_days:
		if day.working_day_ordinal == ordinal:
			return day
	return null


func to_dict() -> Dictionary:
	var days := []
	for day in campaign_days:
		days.append({
			"scheduled_trades": day.scheduled_trades.map(func(t): return String(t)),
			"story_beat_id": String(day.story_beat_id),
		})
	return {
		"campaign_start_utc": campaign_start_utc,
		"campaign_start_epoch_day": campaign_start_epoch_day,
		"days": days,
	}


func from_dict(d: Dictionary) -> void:
	clear()
	campaign_start_utc = int(d.get("campaign_start_utc", 0))
	if not has_campaign():
		return
	campaign_start_epoch_day = int(d.get("campaign_start_epoch_day", 0))
	generate_calendar(campaign_start_epoch_day)
	var days: Array = d.get("days", [])
	for i in mini(days.size(), campaign_days.size()):
		var src: Dictionary = days[i]
		var trades: Array[StringName] = []
		for t in src.get("scheduled_trades", []):
			trades.append(StringName(t))
		campaign_days[i].scheduled_trades = trades
		campaign_days[i].story_beat_id = StringName(src.get("story_beat_id", ""))
