# tools/debug/soak_fortnight.gd — JIOH-25: the headless fortnight soak.
#
#   godot --headless --path . --script res://tools/debug/soak_fortnight.gd
#
# Stamps a fresh campaign, then walks all fourteen days by moving the
# WorldClock offset, the same seam the console uses. The profile mixes days
# played boundary by boundary, partial days, skipped days and both weekends
# unattended. At every step it asserts:
#   - campaign day is monotonic and within 1..14
#   - the phase matches an independent expectation for that wall time
#   - CampaignState serialises and deserialises to an identical dictionary
#   - node and orphan counts have not grown
#   - no error or warning was logged
# Exits non-zero on the first failure, printing the day, phase and wall time.
extends SceneTree

const START_EPOCH_DAY := 20733  # a Wednesday, so both weekends fall mid-run
const STEP := 15 * 60

# How each day is played. "full": every 15 minutes, 06:00-19:00.
# "partial": the morning only, then away until tomorrow. "skip": not opened.
const PROFILE := {
	1: "full", 2: "partial", 3: "skip", 4: "skip", 5: "skip",
	6: "full", 7: "full", 8: "skip", 9: "partial", 10: "full",
	11: "skip", 12: "skip", 13: "partial", 14: "full",
}


class SoakLogger extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		count += 1
		last = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]
		if error_type == ERROR_TYPE_WARNING:
			last = "warning: " + last


var _logger := SoakLogger.new()
var _fake_real := 0.0
var _last_day := 0
var _steps := 0
var _base_nodes := 0
var _base_orphans := 0
var _failed := false


func _initialize() -> void:
	OS.add_logger(_logger)
	# Autoloads are added after _initialize; start on the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var clock := root.get_node("WorldClock")
	var campaign := root.get_node("CampaignState")
	var phases := root.get_node("DayPhase")

	campaign.slot = 98  # never a real player slot
	clock.set_time_zone_bias_override(0)
	_fake_real = START_EPOCH_DAY * 86400 + 9 * 3600
	clock.set_time_source(func() -> float: return _fake_real)
	campaign.new_campaign()
	phases.resync()
	_base_nodes = root.get_child_count() + _count_nodes(root)
	_base_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	for day in range(1, 15):
		var midnight := (START_EPOCH_DAY + day - 1) * 86400
		match PROFILE[day]:
			"full":
				for t in range(midnight + 6 * 3600, midnight + 19 * 3600 + 1, STEP):
					if not _step(clock, campaign, phases, t, day):
						_finish(1)
						return
			"partial":
				for t in range(midnight + 6 * 3600, midnight + 11 * 3600 + 1, STEP):
					if not _step(clock, campaign, phases, t, day):
						_finish(1)
						return
			"skip":
				pass
		# Always look once at the end of the day so the next day's jump is a
		# real overnight absence, and a skipped day is one long one.
		if not _step(clock, campaign, phases, midnight + 23 * 3600 + 59 * 60, day):
			_finish(1)
			return

	print("SOAK OK: %d steps across 14 days" % _steps)
	_finish(0)


func _step(clock: Node, campaign: Node, phases: Node, utc: int, expect_day: int) -> bool:
	_steps += 1
	clock.jump_to(utc)
	clock.poll()
	var day: int = clock.get_campaign_day()
	var minute := (utc % 86400) / 60
	var where := "day %d, %02d:%02d, phase %s" % [day, minute / 60, minute % 60,
		phases.phase_name(phases.phase)]

	if day != expect_day or day < _last_day or day < 1 or day > 14:
		return _fail("campaign day %d, expected %d (last %d)" % [day, expect_day, _last_day], where)
	_last_day = day

	var expected := _expected_phase(campaign.get_day(day).is_working_day, minute)
	if phases.phase != expected:
		return _fail("phase %s, expected %s" % [phases.phase_name(phases.phase),
			phases.phase_name(expected)], where)

	var saved: Dictionary = campaign.to_dict()
	campaign.from_dict(saved)
	if campaign.to_dict() != saved:
		return _fail("CampaignState does not round-trip", where)

	var nodes := root.get_child_count() + _count_nodes(root)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if nodes > _base_nodes or orphans > _base_orphans:
		return _fail("node count %d (base %d), orphans %d (base %d)" % [nodes,
			_base_nodes, orphans, _base_orphans], where)

	if _logger.count > 0:
		return _fail("logged: %s" % _logger.last, where)
	return true


## An independent statement of the default schedule (resources/campaign/
## day_schedule.tres). If someone retunes the schedule, update this too.
func _expected_phase(working: bool, minute: int) -> int:
	if not working:
		return 0
	if minute >= 18 * 60: return 0
	if minute >= 16 * 60 + 30: return 5
	if minute >= 15 * 60 + 30: return 4
	if minute >= 10 * 60: return 3
	if minute >= 7 * 60 + 30: return 2
	if minute >= 6 * 60 + 30: return 1
	return 0


func _count_nodes(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		n += 1 + _count_nodes(child)
	return n


func _fail(what: String, where: String) -> bool:
	if not _failed:
		_failed = true
		print("SOAK FAIL at %s: %s" % [where, what])
	return false


func _finish(code: int) -> void:
	root.get_node("WorldClock").set_time_source(Callable())
	var dir := ProjectSettings.globalize_path(root.get_node("CampaignState").save_dir())
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	quit(code)
