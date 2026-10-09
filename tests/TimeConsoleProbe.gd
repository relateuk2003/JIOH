# tests/TimeConsoleProbe.gd — JIOH-25 console acceptance criteria.
extends Probe

const TimeConsole := preload("res://tools/debug/time_console.gd")

var events: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var console: Node = DebugHooks.get_node_or_null("TimeConsole")
	check(console != null, "debug build mounts the time console")
	if console == null:
		finish()
		return
	DayPhase.phase_changed.connect(func(_a, b): events.append(DayPhase.phase_name(b)))
	WorldClock.day_rolled.connect(func(d): events.append("day%d" % d))

	use_fake_clock(MON_2026_10_05, 9, 0)
	CampaignState.new_campaign()
	events.clear()
	var out: String = console.execute("goto 11 wind_down")
	check(WorldClock.get_campaign_day() == 11 and DayPhase.phase == DayPhase.Phase.WIND_DOWN,
		"goto 11 wind_down lands on day 11 wind-down (%s)" % out)
	check(events.count("day11") == 1 and events.count("day2") == 1, "every intervening day rolled once")
	# Monday start: days 1 (from 09:00), 2..5 and 8..11 are working.
	check(events.count("handout") == 8 and events.count("cutoff") == 9,
		"intervening boundaries fired through the normal path (handout x%d, cutoff x%d)" % [events.count("handout"), events.count("cutoff")])

	var a: String = console.execute("goto 5 handout")
	var b: String = console.execute("goto 5 handout")
	check(a.ends_with(b.get_slice("\n", b.count("\n"))), "repeated goto reports identical day, phase and offset")
	check(console.execute("now") == b.get_slice("\n", b.count("\n")), "now matches the last jump")

	console.execute("freeze")
	var frozen := WorldClock.now_unix()
	var frozen_phase := DayPhase.phase
	advance(7200)
	check(WorldClock.now_unix() == frozen and DayPhase.phase == frozen_phase,
		"frozen clock does not advance with real time and no boundary fires")
	console.execute("thaw")
	advance(60)
	check(WorldClock.get_now().minute == 31, "thaw resumes from the frozen time without a jump")

	console.execute("skip 2h")
	check(WorldClock.get_now().hour == 9 and WorldClock.get_now().minute == 31, "skip 2h moves the clock two hours")
	check(TimeConsole.parse_duration("45m") == 2700 and TimeConsole.parse_duration("3d") == 259200
		and TimeConsole.parse_duration("x") == 0, "durations parse")
	check(console.execute("goto 1 handout").begins_with("WARNING"), "jumping backwards warns")

	finish()
