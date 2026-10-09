# scripts/ui/pause_screen.gd — what is on screen while the mouse is let go.
#
# The office does not stop: the clock is real, so this is a pause for the
# player's hands, not for the world, and it says so. The build version sits
# in the corner (JIOH-60) so a screenshot of a problem says which build it
# came from.
class_name PauseScreen
extends CanvasLayer

const SCREEN := Vector2(320, 240)

var version_text: PixelText
var _shade: ColorRect
## Up from the moment the player lets go of the mouse until they take it back.
var _released := false


func _ready() -> void:
	layer = 90
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.6)
	_shade.size = SCREEN
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var title := _text("PAUSED", JiohFonts.Face.DISPLAY, Vector2(0, 92))
	title.size.x = SCREEN.x
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := _text("The office carries on without you.\nClick to go back.", JiohFonts.Face.BODY, Vector2(0, 116))
	note.size.x = SCREEN.x
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_text = _text(BuildInfo.label(), JiohFonts.Face.BODY, Vector2(0, SCREEN.y - 12))
	version_text.size.x = SCREEN.x - 4
	version_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"release_mouse"):
		_released = true
	elif event is InputEventMouseButton and event.pressed:
		_released = false
	_refresh()


func _process(_delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_released = false
	_refresh()


func is_showing() -> bool:
	return visible


func _refresh() -> void:
	var p := InteractionManager.player
	visible = _released and p != null and is_instance_valid(p) \
		and not (FMVPlayer.current and is_instance_valid(FMVPlayer.current) and FMVPlayer.current.is_playing())


func _text(t: String, face: JiohFonts.Face, at: Vector2) -> PixelText:
	var l := PixelText.new()
	l.face = face
	l.ink = Color(0.85, 0.85, 0.8)
	l.text = t
	l.position = at
	add_child(l)
	return l
