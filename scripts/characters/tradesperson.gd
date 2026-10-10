# scripts/characters/tradesperson.gd — a trade in the flesh, grey-boxed.
#
# Until the blank-face model, rig and animation set lands, the figure is built
# from the trade's BodyProfileData: height, build and kit colour are what the
# player reads through the hatch first. There is no face. Named animations
# are logged and posed procedurally so the systems driving them (handout,
# reactions, waiting) can be written and tested against the real names now.
class_name Tradesperson
extends Node3D

signal arrived

## Widths by BodyProfileData.Build: shoulders, then depth.
const BUILD_WIDTH := [0.38, 0.44, 0.5, 0.56]
const SKIN := Color(0.62, 0.5, 0.42)

var data: TradespersonData
var slot: ArrivalSlot
## Every animation asked for, in order. The rig will play these; tests read it.
var anim_log: Array[StringName] = []
var current_anim: StringName = &""
var hand_r: Marker3D
var head: Node3D
var _walk_target: Variant = null


static func make(trade: TradespersonData, arrival: ArrivalSlot = null) -> Tradesperson:
	var t := Tradesperson.new()
	t.name = "Trade_%s" % trade.trade_id
	t.data = trade
	t.slot = arrival
	t._build()
	return t


func play(anim: StringName) -> void:
	anim_log.append(anim)
	current_anim = anim
	var pitch := 0.0
	match anim:
		&"receive", &"read_document", &"sign_document":
			pitch = -0.5
		&"read_document_recheck":
			pitch = -0.75
		&"idle_impatient", &"waiting_check_watch":
			pitch = -0.2
	head.rotation.x = pitch


## Walks in a straight line at the trade's gait. Presentation only: nothing
## that matters to the campaign waits on a walk finishing.
func walk_to(point: Vector3) -> void:
	_walk_target = point
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.01:
		look_at(flat, Vector3.UP, true)


func is_walking() -> bool:
	return _walk_target != null


## Snaps to a point, for restores and tests.
func place_at(point: Vector3, facing: Vector3) -> void:
	_walk_target = null
	global_position = point
	look_at(point + facing, Vector3.UP, true)


func _process(delta: float) -> void:
	if _walk_target == null:
		return
	var to: Vector3 = _walk_target - global_position
	to.y = 0
	var step := data.body_profile.gait_speed * delta
	if to.length() <= step:
		global_position = _walk_target
		_walk_target = null
		arrived.emit()
	else:
		global_position += to.normalized() * step


func _build() -> void:
	var b := data.body_profile
	var h := b.height_m
	var w: float = BUILD_WIDTH[b.build]
	var kit := b.kit_colour
	var legs := Color(0.2, 0.2, 0.22) if kit.v > 0.6 else kit.darkened(0.35)
	# Faces local +Z.
	PropMesh.box(self, "Legs", Vector3(0, h * 0.235, 0), Vector3(w * 0.8, h * 0.47, w * 0.5), legs)
	PropMesh.box(self, "Torso", Vector3(0, h * 0.62, 0), Vector3(w, h * 0.3, w * 0.55), kit)
	PropMesh.box(self, "ArmL", Vector3(-w * 0.62, h * 0.6, 0), Vector3(w * 0.22, h * 0.32, w * 0.3), kit)
	PropMesh.box(self, "ArmR", Vector3(w * 0.62, h * 0.6, 0.04), Vector3(w * 0.22, h * 0.32, w * 0.3), kit)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, h * 0.8, 0)
	add_child(head)
	# The blank face: a plain skin-toned block, nothing on it.
	PropMesh.box(head, "Blank", Vector3(0, h * 0.075, 0), Vector3(w * 0.42, h * 0.15, w * 0.45), SKIN)
	hand_r = Marker3D.new()
	hand_r.name = "Attach_HandR"
	hand_r.position = Vector3(w * 0.3, h * 0.55, w * 0.45)
	hand_r.rotation = Vector3(-1.1, 0, 0)
	add_child(hand_r)
