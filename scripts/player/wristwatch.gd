# scripts/player/wristwatch.gd — JIOH-67: the only clock the player carries.
#
# A cheap digital watch on a grey resin strap, parented to the camera rig.
# Held, not toggled: it comes up over a third of a second while the button is
# down and drops when it is let go. While it is up the hands are busy, so the
# interaction ray is blocked. It reads WorldClock and nothing else, and
# redraws only when the minute changes.
class_name Wristwatch
extends Node3D

signal raised
signal lowered

const FACE_PIXELS := Vector2i(64, 32)
const FACE_M := Vector2(0.05, 0.025)
const LCD := Color(0.56, 0.6, 0.5)
const SEGMENT := Color(0.1, 0.12, 0.1)
const STRAP := Color(0.18, 0.18, 0.19)
const RAISE_SECONDS := 0.35
## Down out of view, and up in the lower right of the frame.
static var DOWN := Transform3D(Basis.from_euler(Vector3(0.9, 0.0, 0.5)), Vector3(0.1, -0.2, -0.17))
static var UP := Transform3D(Basis.from_euler(Vector3(0.12, -0.18, 0.0)), Vector3(0.068, -0.05, -0.16))

var rig: Node3D
var anim: AnimationPlayer
var time_label: PixelText
var day_label: PixelText
var up := false
## Times the face has been drawn; the watch never redraws per frame.
var redraws := 0
var _viewport: SubViewport


func _ready() -> void:
	_build()
	WorldClock.minute_elapsed.connect(_redraw)
	_redraw()


## The single gate: no raising with a document in hand, while examining, or
## while the terminal or the desk has the player.
func can_raise() -> bool:
	if up:
		return false
	if InteractionManager.examined_item:
		return false
	var held := InteractionManager.carried_item
	if held and is_instance_valid(held) and held.tags.any(func(t): return t in [&"paper_stack", &"hatch_note", &"document"]):
		return false
	var p := InteractionManager.player
	return not (p and is_instance_valid(p) and p.movement_locked)


func press() -> void:
	if up and _toggle_mode():
		release()
		return
	if not can_raise():
		return
	up = true
	InteractionManager.set_blocked(self, true)
	anim.play(&"raise")
	raised.emit()


func release() -> void:
	if not up:
		return
	up = false
	InteractionManager.set_blocked(self, false)
	anim.play(&"lower")
	lowered.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"check_watch"):
		press()
	elif event.is_action_released(&"check_watch") and not _toggle_mode():
		release()


## JIOH-11 accessibility: press to raise, press again to lower.
func _toggle_mode() -> bool:
	return bool(CampaignState.settings.get("watch_toggle", false))


## Hours and minutes, 24-hour, and the day. No seconds.
func face_text() -> String:
	var now := WorldClock.get_now()
	var names := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
	return "%02d:%02d %s" % [now.hour, now.minute, names[now.weekday]]


func _redraw() -> void:
	var parts := face_text().split(" ")
	time_label.text = parts[0]
	day_label.text = parts[1]
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	redraws += 1


func face_image() -> Image:
	return _viewport.get_texture().get_image()


func _build() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	rig.transform = DOWN
	add_child(rig)
	PropMesh.box(rig, "Strap", Vector3(0, 0, -0.004), Vector3(0.03, 0.11, 0.006), STRAP)
	PropMesh.box(rig, "Case", Vector3(0, 0, -0.001), Vector3(FACE_M.x + 0.008, FACE_M.y + 0.012, 0.008), Color(0.24, 0.24, 0.25))
	_viewport = SubViewport.new()
	_viewport.size = FACE_PIXELS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var bg := ColorRect.new()
	bg.color = LCD
	bg.size = Vector2(FACE_PIXELS)
	_viewport.add_child(bg)
	time_label = PixelText.new()
	time_label.face = JiohFonts.Face.TERMINAL
	time_label.pixel_scale = 2
	time_label.ink = SEGMENT
	time_label.position = Vector2(2, -1)
	_viewport.add_child(time_label)
	day_label = PixelText.new()
	day_label.face = JiohFonts.Face.TERMINAL
	day_label.ink = SEGMENT
	day_label.position = Vector2(2, 20)
	_viewport.add_child(day_label)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = QuadMesh.new()
	(face.mesh as QuadMesh).size = FACE_M
	face.position = Vector3(0, 0, 0.0035)
	var mat := PixelDecal.READABLE.duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"albedo_texture", _viewport.get_texture())
	face.material_override = mat
	rig.add_child(face)
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"raise", _clip(DOWN, UP))
	lib.add_animation(&"lower", _clip(UP, DOWN))
	anim.add_animation_library(&"", lib)


func _clip(from: Transform3D, to: Transform3D) -> Animation:
	var a := Animation.new()
	a.length = RAISE_SECONDS
	var pos := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pos, ^"Rig")
	a.position_track_insert_key(pos, 0.0, from.origin)
	a.position_track_insert_key(pos, RAISE_SECONDS, to.origin)
	var rot := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(rot, ^"Rig")
	a.rotation_track_insert_key(rot, 0.0, from.basis.get_rotation_quaternion())
	a.rotation_track_insert_key(rot, RAISE_SECONDS, to.basis.get_rotation_quaternion())
	return a
