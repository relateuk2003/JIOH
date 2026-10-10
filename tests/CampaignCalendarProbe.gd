# tests/CampaignCalendarProbe.gd — JIOH-15 acceptance criteria.
extends Probe


func _ready() -> void:
	# Wednesday start: 14 consecutive days, 4 weekend, 10 working.
	use_fake_clock(WED_2026_10_07, 9, 0)
	CampaignState.new_campaign()
	var days := CampaignState.campaign_days
	check(days.size() == 14, "fourteen days generated")
	check(days[0].date == "2026-10-07", "day 1 is the start date (got %s)" % days[0].date)
	var consecutive := true
	for i in range(1, days.size()):
		consecutive = consecutive and days[i].epoch_day == days[i - 1].epoch_day + 1
	check(consecutive, "dates are consecutive")
	check(days.filter(func(d): return not d.is_working_day).size() == 4, "exactly four weekend days")
	check(days.filter(func(d): return d.is_working_day).size() == 10, "exactly ten working days")
	var shape := "".join(days.map(func(d): return "W" if d.is_working_day else "-"))
	check(shape == "WWW--WWWWW--WW", "Wednesday shape is 3 working, weekend, 5, weekend, 2 (got %s)" % shape)

	# Saturday start: weekend state, nothing scheduled, not stalled.
	use_fake_clock(SAT_2026_10_10, 9, 0)
	CampaignState.new_campaign()
	check(not WorldClock.is_working_day(), "Saturday start is not a working day")
	check(DayPhase.phase == DayPhase.Phase.CLOSED, "Saturday start finds the building closed")
	check(CampaignState.get_day(1).scheduled_trades.is_empty(), "no trades scheduled on a Saturday start")
	check(WorldClock.get_campaign_day() == 1 and not CampaignState.is_concluded(), "Saturday start is day 1 of a live campaign")
	check(CampaignState.get_day(3).is_working_day, "the Monday after a Saturday start is a working day")

	# Stamped six days ago reads day 7, from a date difference.
	use_fake_clock(WED_2026_10_07, 9, 0)
	CampaignState.new_campaign()
	set_local(WED_2026_10_07 + 6, 9, 0)
	check(WorldClock.get_campaign_day() == 7, "six days after the stamp is day 7 (got %d)" % WorldClock.get_campaign_day())
	check(not ("day_counter" in CampaignState), "no stored day counter exists")

	# Past day 14 the campaign is concluded.
	set_local(WED_2026_10_07 + 14, 9, 0)
	check(CampaignState.is_concluded(), "day 15 is the concluded state")

	# Working-day ordinal 4 from a Thursday start lands on Tuesday.
	use_fake_clock(THU_2026_10_08, 9, 0)
	CampaignState.new_campaign()
	var wd4 := CampaignState.day_for_working_ordinal(4)
	check(wd4 != null and WorldClock.weekday_of(wd4.epoch_day) == 2, "working day 4 of a Thursday start is a Tuesday")

	# Save round trip.
	CampaignState.campaign_days[2].story_beat_id = &"beat_x"
	var saved := CampaignState.to_dict()
	CampaignState.clear()
	CampaignState.from_dict(saved)
	check(CampaignState.to_dict() == saved, "campaign state round-trips through to_dict/from_dict")
	check(CampaignState.get_day(3).story_beat_id == &"beat_x", "authored day data survives the round trip")

	finish()
