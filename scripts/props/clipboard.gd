# scripts/props/clipboard.gd — JIOH-71: the hardboard clipboard every held
# document is clipped to. One exists in the building and the player carries
# it in the left hand; it is only seen while there is paper on it.
#
# Two sheets of paper: the leaf on top, hinged at the clip, and the page
# beneath it. Turning a page flips the leaf up and over the clip and shows
# what was underneath; turning back brings the previous leaf down. The board
# faces the camera along its local +Z; the top of the page is local +Y.
class_name Clipboard
extends Node3D

## A page turn has played out; the leaf has landed.
signal turn_finished

const BOARD := Vector2(0.23, 0.32)
const TURN_SECONDS := 0.25
const OVER := -175.0  # degrees a turned leaf travels, up and over the clip
## Held, the page is drawn at the size it appears on the 320x240 screen, so
## the bitmap faces land one texel to one screen pixel (JIOH-63).
const HELD_PIXELS := Vector2i(120, 170)

var leaf: SheetView
var under: SheetView
var hinge: Node3D
var pen: Node3D
var anim: AnimationPlayer
## Turns played, for tests.
var turns := 0
var _sound: AudioStreamPlayer


func _ready() -> void:
	var board := Node3D.new()
	board.name = "Board"
	# Sheets lie in their local XZ plane, top at -Z; stand them up facing us.
	board.rotation = Vector3(PI / 2.0, 0, 0)
	add_child(board)
	PropMesh.box(board, "Hardboard", Vector3(0, -0.005, 0), Vector3(BOARD.x, 0.005, BOARD.y), Color(0.45, 0.33, 0.2))
	var top := -BOARD.y / 2.0
	PropMesh.box(board, "Clip", Vector3(0, 0.006, top + 0.012), Vector3(0.09, 0.008, 0.024), Color(0.62, 0.63, 0.65))
	under = SheetView.make(null, HELD_PIXELS)
	under.name = "Under"
	under.position = Vector3(0, 0.0008, 0.01)
	board.add_child(under)
	hinge = Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0, 0.0016, 0.01 - SheetView.SIZE.y / 2.0)
	board.add_child(hinge)
	leaf = SheetView.make(null, HELD_PIXELS)
	leaf.name = "Leaf"
	leaf.position = Vector3(0, 0, SheetView.SIZE.y / 2.0)
	hinge.add_child(leaf)
	pen = Node3D.new()
	pen.name = "Biro"
	board.add_child(pen)
	var barrel := PropMesh.box(pen, "Barrel", Vector3(0, 0.004, 0.06), Vector3(0.008, 0.008, 0.12), Color(0.9, 0.9, 0.92))
	barrel.rotation.x = 0.0
	PropMesh.box(pen, "Cap", Vector3(0, 0.004, 0.115), Vector3(0.009, 0.009, 0.02), Color(0.13, 0.19, 0.52))
	rest_pen()
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"turn_next", _turn_clip(0.0, OVER))
	lib.add_animation(&"turn_previous", _turn_clip(OVER, 0.0))
	anim.add_animation_library(&"", lib)
	# After the last key is applied, so resetting the hinge then sticks.
	anim.animation_finished.connect(func(_n): turn_finished.emit())
	_sound = AudioStreamPlayer.new()
	_sound.name = "PageSound"
	_sound.stream = _rustle()
	_sound.volume_db = -10.0
	add_child(_sound)


## Shows a page on top, and the one after it beneath (blank board if none).
func show_pages(top: DocumentInstance, beneath: DocumentInstance) -> void:
	hinge.rotation = Vector3.ZERO
	leaf.show_document(top)
	under.visible = beneath != null
	if beneath:
		under.show_document(beneath)


## Flips the top leaf over, revealing `beneath`; `after` lies under that.
func turn_next(beneath: DocumentInstance) -> void:
	under.visible = true
	under.show_document(beneath)
	_play(&"turn_next")


## Brings the previous leaf back down over the current page.
func turn_previous(previous: DocumentInstance, current: DocumentInstance) -> void:
	under.visible = true
	under.show_document(current)
	leaf.show_document(previous)
	hinge.rotation_degrees = Vector3(OVER, 0, 0)
	_play(&"turn_previous")


## The biro's nib on a box, in the page's 0..1 space; null puts it back on
## the clip.
func point_pen(uv: Variant) -> void:
	if uv == null:
		rest_pen()
		return
	var at := SheetView.local_of_uv(uv) + Vector3(0, 0.0, 0.01)
	pen.position = at + Vector3(0, 0.004, 0)
	pen.rotation = Vector3(-0.35, 0.5, 0)


func rest_pen() -> void:
	pen.position = Vector3(BOARD.x / 2.0 - 0.012, 0.0, -BOARD.y / 2.0 + 0.04)
	pen.rotation = Vector3.ZERO


func refresh(live_key: StringName = &"", live_value: Variant = null) -> void:
	leaf.refresh(live_key, live_value)


func _play(clip: StringName) -> void:
	anim.stop()
	anim.play(clip)
	_sound.play()
	turns += 1


func _turn_clip(from_deg: float, to_deg: float) -> Animation:
	var a := Animation.new()
	a.length = TURN_SECONDS
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, ^"Board/Hinge")
	a.rotation_track_insert_key(t, 0.0, Quaternion(Vector3.RIGHT, deg_to_rad(from_deg)))
	a.rotation_track_insert_key(t, TURN_SECONDS, Quaternion(Vector3.RIGHT, deg_to_rad(to_deg)))
	return a


## A short dry rustle: filtered noise with a fast attack. A placeholder until
## the JIOH-8 paper set is recorded.
static func _rustle() -> AudioStreamWAV:
	var data := PackedByteArray()
	var rate := HatchSounds.RATE
	var prev := 0.0
	for i in int(rate * 0.18):
		var t := float(i) / rate
		var n := HatchSounds.randf_noise(i * 7 + 13)
		prev = prev * 0.55 + n * 0.45
		var env := minf(t * 60.0, 1.0) * exp(-t * 18.0)
		HatchSounds._push(data, prev * env * 0.7)
	return HatchSounds._wav(data)
