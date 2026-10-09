# tests/WorldClockProbe.gd — JIOH-14 acceptance criteria.
extends Probe

var minutes := 0


func _ready() -> void:
	WorldClock.minute_elapsed.connect(func(): minutes += 1)

	# One OS minute fires minute_elapsed exactly once and get_now follows.
	use_fake_clock(WED_2026_10_07, 9, 0)
	advance(0.5)
	minutes = 0
	advance(59.5)
	check(minutes == 1, "minute_elapsed fires once when the clock reaches the next minute")
	advance(30)
	check(minutes == 1, "minute_elapsed does not fire again within the same minute")
	var now := WorldClock.get_now()
	check(now.hour == 9 and now.minute == 1, "get_now reflects the new minute (got %02d:%02d)" % [now.hour, now.minute])

	# A +48h offset is seen identically by every system.
	CampaignState.new_campaign()
	WorldClock.set_debug_offset(48 * 3600)
	WorldClock.poll()
	now = WorldClock.get_now()
	check(now.day == 9 and now.hour == 9, "offset +48h moves local time to Friday 09:01 (got day %d %02d:%02d)" % [now.day, now.hour, now.minute])
	check(WorldClock.get_campaign_day() == 3, "campaign day agrees with the offset (got %d)" % WorldClock.get_campaign_day())
	check(DayPhase.phase == DayPhase.Phase.HANDOUT, "phase machine agrees with the offset (got %s)" % DayPhase.phase_name(DayPhase.phase))
	check(WorldClock.get_phase() == DayPhase.phase, "WorldClock.get_phase delegates to DayPhase")
	check(absf(WorldClock.offset_seconds - 48 * 3600) < 1.0, "offset_seconds reports +48h")

	# Local wall time, not UTC, outside UTC.
	use_fake_clock(WED_2026_10_07, 9, 0, 60)
	now = WorldClock.get_now()
	check(now.hour == 9, "in UTC+1 the local hour is 09 (got %02d)" % now.hour)
	check(int(now.unix_utc) % 86400 == 8 * 3600, "UTC underneath is 08:00")

	# Freeze and fast-forward.
	use_fake_clock(WED_2026_10_07, 9, 0)
	WorldClock.time_scale = 0.0
	advance(3600)
	check(WorldClock.get_now().hour == 9 and WorldClock.get_now().minute == 0, "time_scale 0 freezes the world")
	WorldClock.time_scale = 1.0
	advance(60)
	check(WorldClock.get_now().minute == 1, "thaw resumes from the frozen time without a jump")
	WorldClock.time_scale = 60.0
	advance(60)
	check(WorldClock.get_now().hour == 10 and WorldClock.get_now().minute == 1, "time_scale 60 runs an hour per real minute")
	WorldClock.time_scale = 1.0

	finish()
