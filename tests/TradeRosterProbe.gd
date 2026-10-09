# tests/TradeRosterProbe.gd — JIOH-21 acceptance criteria.
extends Probe


func _ready() -> void:
	remove_test_saves()
	var roster := TradeRoster.shipped()
	var ids := roster.ids()
	check(roster.trades.size() == 10, "the roster holds exactly ten trades")
	check(ids.all(func(id): return ids.count(id) == 1), "every trade_id is unique")
	check(ids == PackMatrix.TRADES, "roster order matches the pack matrix and the pigeon holes")

	var pairs := roster.trades.map(func(t): return [t.patience_seconds, t.error_tolerance])
	check(pairs.all(func(p): return pairs.count(p) == 1), "no two trades share patience and tolerance")
	var patience := roster.trades.map(func(t): return t.patience_seconds)
	patience.sort()
	var median: float = (patience[4] + patience[5]) / 2.0
	check(roster.trades.any(func(t): return t.patience_seconds > median and t.error_tolerance <= 1),
		"someone is patient and intolerant of a bad pack")
	check(roster.trades.any(func(t): return t.patience_seconds < median and t.error_tolerance >= 3),
		"someone is impatient and shrugs at a bad pack")
	var gas := roster.get_trade(&"gas_engineer")
	check(gas.punctuality.window_start_minutes == 0 and gas.punctuality.window_end_minutes == 4
		and gas.punctuality.variance_minutes == 1, "the gas engineer's window is +0 to +4, variance 1")
	var dec := roster.get_trade(&"decorator")
	check(dec.punctuality.window_start_minutes == 100 and dec.punctuality.window_end_minutes == 140
		and dec.punctuality.variance_minutes == 25, "the decorator's is +100 to +140, variance 25")
	check(roster.get_trade(&"cleaner").punctuality.lets_self_in, "the cleaner lets herself in")
	check(roster.trades.all(_fully_voiced), "every trade has a voice set with a line for every situation, and a body")
	check(RosterValidator.problems(roster, load("res://resources/documents/pack_matrix.tres")).is_empty(),
		"the shipped roster validates")

	# The validator names a trade whose window leaves Handout.
	var bad := roster.duplicate(true) as TradeRoster
	bad.trades[3].punctuality.window_end_minutes = 170
	var probs := RosterValidator.problems(bad)
	check(probs.size() == 1 and "plasterer" in probs[0] and "10:00" in probs[0], "a window past 10:00 fails and names the trade (%s)" % [probs])
	bad.trades[3].punctuality.window_end_minutes = 30
	bad.trades[5].punctuality.window_start_minutes = -5
	probs = RosterValidator.problems(bad)
	check(probs.size() == 1 and "flooring_fitter" in probs[0], "a window before 07:30 fails unless they let themselves in")
	bad.trades[5].punctuality.window_start_minutes = 30
	bad.trades[1].voice_set = null
	bad.trades[2].trade_id = &"electrician"
	probs = RosterValidator.problems(bad)
	check(Array(probs).any(func(p): return "carpenter: no voice set" in p)
		and Array(probs).any(func(p): return "duplicate trade_id" in p), "missing voice sets and duplicate ids fail")
	bad.trades[2].trade_id = &""
	check(Array(RosterValidator.problems(bad)).any(func(p): return "unassigned" in p), "an unassigned trade_id fails")

	# Relationships: defaults on first request, never null.
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	var r := CampaignState.get_relationship(&"gas_engineer")
	check(r != null and r.strikes == 0 and not r.has_walked, "a trade never seen yet has a default relationship")
	check(CampaignState.get_relationship(&"gas_engineer") == r, "and it is the same object on the next request")

	# Strikes against three trades survive a close and relaunch exactly.
	var on_disk := FileAccess.get_file_as_string("res://resources/trades/electrician.tres")
	CampaignState.get_relationship(&"electrician").strikes = 2
	CampaignState.get_relationship(&"plasterer").strikes = 1
	var sc := CampaignState.get_relationship(&"scaffolder")
	sc.strikes = 3
	sc.goodwill = -1.5
	sc.has_walked = true
	sc.outstanding_query = &"permit_date"
	sc.days_since_last_success = 4
	var before: Dictionary = CampaignState.to_dict().relationships
	CampaignState.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	CampaignState.clear()
	CampaignState.resume()
	var after: Dictionary = CampaignState.to_dict().relationships
	check(before == after, "every relationship restores exactly")
	var sc2 := CampaignState.get_relationship(&"scaffolder")
	check(sc2.strikes == 3 and sc2.goodwill == -1.5 and sc2.has_walked and sc2.outstanding_query == &"permit_date"
		and sc2.days_since_last_success == 4, "the scaffolder's state is whole")
	check(FileAccess.get_file_as_string("res://resources/trades/electrician.tres") == on_disk
		and TradeRoster.shipped().get_trade(&"electrician").error_tolerance == 1, "authored trades are untouched on disk")
	remove_test_saves()
	finish()


func _fully_voiced(t: TradespersonData) -> bool:
	if t.voice_set == null or t.body_profile == null:
		return false
	for s in VoiceSetData.SITUATIONS:
		if t.voice_set.line_for(s, 0) == "":
			return false
	return true
