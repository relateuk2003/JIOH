# tools/debug/time_console.gd — JIOH-25: the time-travel console.
#
# Debug builds only (mounted by autoload/debug_hooks.gd; tools/debug/ is
# excluded from release exports). Toggle with backtick. Every command resolves
# to WorldClock.set_debug_offset() / jump_to() / time_scale; the console never
# writes CampaignState or skips reconciliation, so a jump exercises exactly the
# code a real player's absence would.
#
# Commands: goto <day> <phase>, skip <2h|45m|3d>, freeze, thaw, rate <n>,
# now, reset, help.
extends CanvasLayer

var _panel: PanelContainer
var _log: RichTextLabel
var _entry: LineEdit


func _ready() -> void:
	if not OS.has_feature("debug"):
		queue_free()
		return
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_QUOTELEFT:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_entry.grab_focus()
		get_viewport().set_input_as_handled()


## Runs one command and returns its output. Public so probes can drive it.
func execute(line: String) -> String:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var args := parts.slice(1)
	match parts[0].to_lower():
		"goto":
			return _cmd_goto(args)
		"skip":
			return _cmd_skip(args)
		"freeze":
			WorldClock.time_scale = 0.0
			return "frozen at %s" % _describe_now()
		"thaw":
			WorldClock.time_scale = 1.0
			return "thawed at %s" % _describe_now()
		"rate":
			if args.size() != 1 or not args[0].is_valid_float():
				return "usage: rate <n>"
			WorldClock.time_scale = float(args[0])
			return "rate %sx" % args[0]
		"now":
			return _describe_now()
		"reset":
			return _move_by(-WorldClock.offset_seconds)
		"era":
			# JIOH-66: A/B any sound against its clean source.
			if args.size() != 1 or args[0] not in ["on", "off"]:
				return "usage: era on|off"
			EraBus.set_bypass(args[0] == "off")
			return "era %s" % args[0]
		"tone":
			# JIOH-70: hear a room tone column without moving the clock.
			if args.is_empty():
				return RoomTone.readout()
			if args[0] == "clock":
				RoomTone.clear_force(2.0)
				return "tone follows the clock"
			if StringName(args[0]) not in RoomToneMatrix.COLUMNS:
				return "usage: tone [%s|clock]" % "|".join(RoomToneMatrix.COLUMNS)
			RoomTone.force_column(StringName(args[0]), 2.0)
			return "tone %s" % args[0]
		"help":
			return "goto <day> <phase> | skip <2h|45m|3d> | freeze | thaw | rate <n> | now | reset | era on|off | tone [column|clock]"
	return "unknown command: %s" % parts[0]


func _cmd_goto(args: PackedStringArray) -> String:
	if args.size() != 2 or not args[0].is_valid_int():
		return "usage: goto <day> <phase>  (phases: %s)" % ", ".join(_phase_names())
	if not CampaignState.has_campaign():
		return "no campaign — start one first"
	var minute := _phase_minute(args[1].to_lower())
	if minute < 0:
		return "unknown phase: %s" % args[1]
	var epoch_day := CampaignState.campaign_start_epoch_day + int(args[0]) - 1
	var target := WorldClock.utc_of_local_midnight(epoch_day) + minute * 60
	return _move_to(target)


func _cmd_skip(args: PackedStringArray) -> String:
	if args.size() != 1:
		return "usage: skip <2h|45m|3d>"
	var seconds := parse_duration(args[0])
	if seconds <= 0:
		return "bad duration: %s" % args[0]
	return _move_by(seconds)


func _move_by(seconds: float) -> String:
	return _move_to(WorldClock.now_unix() + int(seconds))


func _move_to(target: int) -> String:
	var backwards := target < WorldClock.now_unix()
	WorldClock.jump_to(target)
	WorldClock.poll()
	var out := _describe_now()
	if backwards:
		# Rewinding should reload the last autosave; until JIOH-36 lands there
		# is no autosave, so the phase machine just resyncs silently.
		DayPhase.resync()
		out = "WARNING: rewound the clock; world state may be inconsistent\n" + out
	return out


func _describe_now() -> String:
	var n := WorldClock.get_now()
	return "day %d · %s · %04d-%02d-%02d %02d:%02d local · utc %d · offset %+ds · rate %sx" % [
		WorldClock.get_campaign_day(), DayPhase.phase_name(DayPhase.phase),
		n.year, n.month, n.day, n.hour, n.minute, n.unix_utc,
		int(WorldClock.offset_seconds), str(WorldClock.time_scale)]


func _phase_minute(phase_name: String) -> int:
	var s := DayPhase.schedule
	match phase_name:
		"pre_open": return s.pre_open_minute
		"handout": return s.handout_minute
		"working": return s.working_minute
		"cutoff": return s.cutoff_minute
		"wind_down": return s.wind_down_minute
		"closed": return s.closed_minute
	return -1


func _phase_names() -> PackedStringArray:
	return ["pre_open", "handout", "working", "cutoff", "wind_down", "closed"]


## "2h" -> 7200, "45m" -> 2700, "3d" -> 259200, "30s" -> 30. 0 if invalid.
static func parse_duration(text: String) -> int:
	if text.length() < 2:
		return 0
	var number := text.substr(0, text.length() - 1)
	if not number.is_valid_int():
		return 0
	var units := {"s": 1, "m": 60, "h": 3600, "d": 86400}
	var unit := text.right(1).to_lower()
	if not units.has(unit):
		return 0
	return int(number) * int(units[unit])


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size = Vector2(0, 240)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	box.add_child(_log)
	_entry = LineEdit.new()
	_entry.placeholder_text = "help"
	_entry.text_submitted.connect(_on_submitted)
	box.add_child(_entry)


func _on_submitted(text: String) -> void:
	_entry.clear()
	_log.add_text("> %s\n%s\n" % [text, execute(text)])
