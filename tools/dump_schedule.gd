# tools/dump_schedule.gd — JIOH-28: the fortnight's arrivals for a seed, for
# eyeballing pacing without playing fourteen days.
#
#   godot --headless --path . res://tools/dump_schedule.tscn -- <seed> [yyyy-mm-dd]
#
# Starts a throwaway campaign in slot 98 on the given Monday (default
# 2026-10-05), assumes every trade is booked every day and nobody is ever
# served, so strikes drift arrivals later as the fortnight goes on.
extends Node

var _fake := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var start := WorldClock.epoch_day_from_civil(2026, 10, 5)
	if args.size() > 1:
		var p := args[1].split("-")
		start = WorldClock.epoch_day_from_civil(int(p[0]), int(p[1]), int(p[2]))
	CampaignState.slot = 98
	_fake = start * 86400 + 6 * 3600 - WorldClock.tz_bias_minutes() * 60
	WorldClock.set_time_source(func() -> float: return _fake)
	CampaignState.new_campaign()
	CampaignState.campaign_seed = seed_value
	var sched := ArrivalScheduler.new()
	sched.roster = TradeRoster.shipped()
	var everyone: Array[StringName] = sched.roster.ids()
	for d in CampaignState.campaign_days:
		d.scheduled_trades = everyone
	print("Arrivals for seed %d (unserved every day)" % seed_value)
	for day in range(1, CampaignState.CAMPAIGN_LENGTH + 1):
		var info := InformationBoard.describe_day(day)
		var line := "day %2d %s " % [day, info.short]
		for slot in sched.build_day_schedule(day):
			var m := WorldClock.local_minute_of_day(slot.arrival_unix)
			line += " %s %02d:%02d" % [_short(slot.trade_id), m / 60, m % 60]
		for id in sched.no_shows_for(day):
			line += " %s --" % _short(id)
		print(line)
		sched.replay_missed_days(day, day)
	sched.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignState.save_path()))
	get_tree().quit()


func _short(id: StringName) -> String:
	return String(id).substr(0, 5)
