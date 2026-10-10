# tests/DayPhaseProbe.gd — JIOH-16 acceptance criteria.
extends Probe

var events: Array[String] = []


func _ready() -> void:
	DayPhase.phase_changed.connect(func(a, b): events.append("%s>%s" % [DayPhase.phase_name(a), DayPhase.phase_name(b)]))
	WorldClock.day_rolled.connect(func(d): events.append("day%d" % d))

	# 07:29 -> 07:30 fires PRE_OPEN -> HANDOUT exactly once.
	use_fake_clock(WED_2026_10_07, 7, 0)
	CampaignState.new_campaign()
	set_local(WED_2026_10_07, 7, 29)
	check(DayPhase.phase == DayPhase.Phase.PRE_OPEN, "07:29 is pre-open")
	events.clear()
	set_local(WED_2026_10_07, 7, 30)
	set_local(WED_2026_10_07, 7, 31)
	check(events == ["pre_open>handout"], "07:30 fires pre_open>handout exactly once (got %s)" % [events])

	# Working day reaches the cutoff.
	set_local(WED_2026_10_07, 15, 30)
	check(DayPhase.phase == DayPhase.Phase.CUTOFF, "15:30 advances to the lodgement cutoff")

	# Last played 08:00, back at 17:00: four transitions, in order.
	use_fake_clock(WED_2026_10_07, 8, 0)
	CampaignState.new_campaign()
	var last_played := WorldClock.now_unix()
	fake_utc += 9 * 3600
	WorldClock.poll()
	events.clear()
	DayPhase.reconcile_from(last_played)
	check(events == ["handout>working", "working>cutoff", "cutoff>wind_down"],
		"08:00 -> 17:00 fires handout>working, working>cutoff, cutoff>wind_down in order (got %s)" % [events])
	# The ticket's wording counts HANDOUT itself as a transition crossed; from
	# 08:00 the player was already in HANDOUT, so it is not re-fired. From 07:00:
	use_fake_clock(WED_2026_10_07, 7, 0)
	CampaignState.new_campaign()
	last_played = WorldClock.now_unix()
	fake_utc += 10 * 3600
	WorldClock.poll()
	events.clear()
	DayPhase.reconcile_from(last_played)
	check(events == ["pre_open>handout", "handout>working", "working>cutoff", "cutoff>wind_down"],
		"07:00 -> 17:00 fires all four boundaries once, in order (got %s)" % [events])

	# Overnight: the 18:00 close fires before the next day rolls.
	set_local(WED_2026_10_07, 17, 0)
	events.clear()
	set_local(WED_2026_10_07 + 1, 8, 0)
	check(events == ["wind_down>closed", "day2", "closed>pre_open", "pre_open>handout"],
		"overnight jump interleaves the close, the day roll and the morning in order (got %s)" % [events])

	# A jump over a weekend rolls each day once and fires nothing on Sat/Sun.
	set_local(WED_2026_10_07 + 2, 18, 30)  # Friday evening, closed
	events.clear()
	set_local(WED_2026_10_07 + 5, 7, 0)  # Monday pre-open
	check(events == ["day4", "day5", "day6", "closed>pre_open"],
		"weekend jump rolls Sat, Sun, Mon then opens Monday (got %s)" % [events])

	# Closed outside hours.
	set_local(WED_2026_10_07 + 5, 19, 0)
	check(DayPhase.phase == DayPhase.Phase.CLOSED, "19:00 is closed")

	# seconds_until_next_phase.
	set_local(WED_2026_10_07 + 6, 7, 0)
	check(int(DayPhase.seconds_until_next_phase()) == 30 * 60, "07:00 is 30 minutes from handout")

	# Moving the cutoff in the schedule resource moves the phase, no code change.
	var original := DayPhase.schedule
	var edited := original.duplicate() as DaySchedule
	edited.cutoff_minute = 14 * 60
	DayPhase.schedule = edited
	set_local(WED_2026_10_07 + 6, 14, 0)
	check(DayPhase.phase == DayPhase.Phase.CUTOFF, "cutoff moved to 14:00 in the schedule occurs at 14:00")
	DayPhase.schedule = original

	finish()
