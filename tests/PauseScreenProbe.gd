# tests/PauseScreenProbe.gd — the pause screen and its version corner (JIOH-60).
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")


func _ready() -> void:
	use_fake_clock(WED_2026_10_07, 11, 0)
	CampaignState.new_campaign()
	var level: Node3D = LEVEL.instantiate()
	add_child(level)
	await _frames(2)
	var pause: PauseScreen = level.get_node("PauseScreen")
	check(not pause.visible, "nothing over the office while playing")
	var esc := InputEventAction.new()
	esc.action = &"release_mouse"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(2)
	check(pause.visible, "letting go of the mouse shows the pause screen")
	check(BuildInfo.version != "" and pause.version_text.text == BuildInfo.label() \
		and BuildInfo.version in pause.version_text.text, "its corner shows the build (%s)" % pause.version_text.text)
	check(BuildInfo.stamp({}).get("build_version") == BuildInfo.version, "reports carry the same version")
	check(CampaignState.to_dict().get("written_by_build") == BuildInfo.version, "and so does the save")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(2)
	check(not pause.visible, "a click takes the player back")
	finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
