# tests/ArrivalProbe.gd — JIOH-28 acceptance criteria.
extends Probe

const SEED := 424242

var seen: Array = []
var no_shows: Array = []


func _ready() -> void:
	remove_test_saves()
	var everyone := TradeRoster.shipped().ids()

	# Same seed, same day: the same morning, every time.
	var s := _fresh(WED_2026_10_07, everyone)
	var first := s.build_day_schedule(6)
	var same := true
	for i in 9:
		var again := s.build_day_schedule(6)
		same = same and again.size() == first.size()
		for j in mini(again.size(), first.size()):
			same = same and again[j].equals(first[j])
	check(first.size() == 10 and same, "build_day_schedule(6) gives the same ten arrivals ten times over")
	var sorted := first.duplicate()
	sorted.sort_custom(func(a, b): return a.arrival_unix < b.arrival_unix)
	check(sorted == first, "slots come in arrival order")
	var handout := WorldClock.utc_of_local_midnight(CampaignState.get_day(6).epoch_day) + 7 * 3600 + 30 * 60
	check(first.all(func(x): return x.trade_id == &"cleaner" or (x.arrival_unix >= handout and x.arrival_unix <= handout + 150 * 60)),
		"everyone but the cleaner arrives inside Handout")
	var cleaner: ArrivalSlot = first.filter(func(x): return x.trade_id == &"cleaner")[0]
	check(cleaner.arrival_unix < handout, "the cleaner is in before the hatch opens")
	check(first.all(func(x): return x.patience_expiry_unix - x.arrival_unix == int(TradeRoster.shipped().get_trade(x.trade_id).patience_seconds)),
		"patience expiry is arrival plus the trade's patience")
	check(s.build_day_schedule(4).size() == 1 and s.build_day_schedule(4)[0].trade_id == &"cleaner",
		"Saturday brings only the cleaner")
	check(s.build_day_schedule(5).is_empty(), "nobody comes on a Sunday")
	s.free()

	# The gas engineer, unblemished, is never more than four minutes late.
	s = _fresh(MON_2026_10_05, everyone)
	var gas_ok := true
	var working := 0
	for day in range(1, 15):
		for slot in s.build_day_schedule(day):
			if slot.trade_id == &"gas_engineer":
				working += 1
				var opens := WorldClock.utc_of_local_midnight(CampaignState.get_day(day).epoch_day) + 7 * 3600 + 30 * 60
				gas_ok = gas_ok and slot.arrival_unix >= opens and slot.arrival_unix - opens <= 4 * 60
	check(working == 10 and gas_ok, "the gas engineer is at the hatch by 07:34 on all ten working days")

	# Strikes drift a trade later, from persisted state.
	var plasterer := TradeRoster.shipped().get_trade(&"plasterer")
	var clean_time := _slot(s.build_day_schedule(2), &"plasterer").arrival_unix
	CampaignState.get_relationship(&"plasterer").strikes = 3
	CampaignState.commit(&"probe", true)
	CampaignState.clear()
	CampaignState.resume()
	var opens2 := WorldClock.utc_of_local_midnight(CampaignState.get_day(2).epoch_day) + 7 * 3600 + 30 * 60
	var late := _slot(s.build_day_schedule(2), &"plasterer").arrival_unix
	check(late == clean_time + roundi(3 * plasterer.punctuality.drift_per_campaign_day * 60)
		and late - opens2 > plasterer.punctuality.window_end_minutes * 60,
		"three strikes put the plasterer after his unblemished window, read back from the save")

	# Drifted past 10:00: no arrival, and a no-show.
	CampaignState.get_relationship(&"decorator").strikes = 12
	check(_slot(s.build_day_schedule(2), &"decorator") == null and &"decorator" in s.no_shows_for(2),
		"a decorator drifted past 10:00 does not arrive")
	s.free()
	set_local(MON_2026_10_05 + 1, 7, 0)
	s = ArrivalScheduler.new()
	s.no_show.connect(func(id, day): no_shows.append([id, day]))
	add_child(s)
	check([&"decorator", 2] in no_shows, "and no_show fires for him on that day (%s)" % [no_shows])
	s.free()

	# A missed morning replays to the morning a watching player saw.
	var watched := _run_days(everyone, true)
	var missed := _run_days(everyone, false)
	check(watched.arrivals == missed.arrivals and watched.arrivals.size() >= 18,
		"days 4 and 5 replay to the arrivals a watching player saw (%d)" % watched.arrivals.size())
	check(watched.relationships == missed.relationships, "and leave the same relationships behind")
	check(watched.relationships.get("scaffolder", {}).get("strikes", 0) == 5,
		"five empty-hatch mornings cost the scaffolder five strikes")

	# The source draws only from locally seeded generators.
	var src := FileAccess.get_file_as_string("res://scripts/systems/arrival_scheduler.gd")
	var global_rng := RegEx.create_from_string("(?<![\\w.])(randi|randf|randfn|randf_range|randi_range|randomize|seed|rand_from_seed)\\s*\\(")
	check(global_rng.search(src) == null, "no global RNG call in arrival_scheduler.gd")
	check(src.contains("RandomNumberGenerator.new()") and src.contains("rng.seed ="), "every draw comes from a seeded RandomNumberGenerator")
	remove_test_saves()
	finish()


func _fresh(start_day: int, everyone: Array[StringName]) -> ArrivalScheduler:
	use_fake_clock(start_day, 6, 0)
	CampaignState.new_campaign()
	CampaignState.campaign_seed = SEED
	for d in CampaignState.campaign_days:
		d.scheduled_trades = everyone
	var s := ArrivalScheduler.new()
	s.roster = TradeRoster.shipped()
	return s


func _slot(slots: Array[ArrivalSlot], id: StringName) -> ArrivalSlot:
	for x in slots:
		if x.trade_id == id:
			return x
	return null


## Days 1-3 watched, then 4 and 5 either watched minute by minute or skipped;
## either way the player is back on day 6. Monday start, nobody ever served.
func _run_days(everyone: Array[StringName], watch: bool) -> Dictionary:
	seen = []
	use_fake_clock(MON_2026_10_05, 6, 0)
	CampaignState.new_campaign()
	CampaignState.campaign_seed = SEED
	for d in CampaignState.campaign_days:
		d.scheduled_trades = everyone
	var s := ArrivalScheduler.new()
	s.arrival_due.connect(func(slot): seen.append([CampaignState.campaign_day_for(slot.arrival_unix), slot.trade_id, slot.arrival_unix]))
	add_child(s)
	for day in range(1, 6):
		if day >= 4 and not watch:
			continue
		set_local(MON_2026_10_05 + day - 1, 6, 0)
		for m in 260:
			advance(60)
	set_local(MON_2026_10_05 + 5, 6, 0)
	var arrivals: Array = seen.filter(func(a): return a[0] in [4, 5])
	if not watch:
		for day in [4, 5]:
			for slot in s.build_day_schedule(day):
				arrivals.append([day, slot.trade_id, slot.arrival_unix])
	var rel: Dictionary = CampaignState.to_dict().relationships
	s.free()
	return {"arrivals": arrivals, "relationships": rel}
