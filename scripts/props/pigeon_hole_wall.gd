# scripts/props/pigeon_hole_wall.gd — JIOH-32: the wooden pigeon hole unit,
# one hole per trade, hand-painted labels on the lips and a drop-down flap
# over each row.
#
# Built from the exported layout when it enters the tree, so the blockout
# needs no hand-placed cubbies; once it is dressed, the geometry can be baked
# into the scene and the build skipped. Front faces local +Z.
#
# At the cutoff the flaps come down over the mouths: the wall closes, visibly,
# rather than the game refusing an input. They stay down through wind-down
# and the night, and go up again at the start of the next working day.
class_name PigeonHoleWall
extends Node3D

const PS1 := preload("res://shaders/ps1_standard.gdshader")
const CUBBY := Vector3(0.30, 0.25, 0.32)
const BOARD := 0.02
const BASE_HEIGHT := 1.0
## The painted strip across the top of each row of mouths.
const FASCIA := 0.05
const FLAP_OPEN_DEGREES := 88.0  # folded up under the shelf, inside the hole

## Hole order, left to right, top row first.
@export var trades: Array[StringName] = [
	&"electrician", &"carpenter", &"gas_engineer", &"plasterer", &"decorator",
	&"flooring_fitter", &"fire_alarm_engineer", &"asbestos_surveyor", &"cleaner", &"scaffolder",
]
## Painted on the lips. Two read alike in a hurry (PLASTERER and PAINTER &
## DEC, FLOORING and FIRE ALARM), on purpose, but never illegibly.
@export var labels: Array[String] = [
	"SPARKS", "CHIPPIES", "GAS", "PLASTERER", "PAINTER & DEC",
	"FLOORING", "FIRE ALARM", "ASBESTOS", "CLEANERS", "SCAFFOLD",
]
@export var columns: int = 5

var holes: Dictionary = {}  # trade -> PigeonHole
var _flaps: Array[Node3D] = []
var _flaps_open := false


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	_build()
	LodgementLedger.lodgement_opened.connect(_set_flaps.bind(true, true))
	LodgementLedger.lodgement_closed.connect(_set_flaps.bind(false, true))
	CampaignState.campaign_started.connect(restore_from_campaign)
	_set_flaps(LodgementLedger.lodgement_open, false)


## Called by the level once the campaign is loaded.
func restore_from_campaign() -> void:
	for hole in holes.values():
		(hole as PigeonHole).restore()
	_set_flaps(LodgementLedger.lodgement_open, false)


func flaps_open() -> bool:
	return _flaps_open


func _set_flaps(open: bool, animate: bool) -> void:
	_flaps_open = open
	for hinge in _flaps:
		var target := Vector3(deg_to_rad(FLAP_OPEN_DEGREES) if open else 0.0, 0, 0)
		if animate and is_inside_tree():
			create_tween().tween_property(hinge, "rotation", target, 0.6) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			hinge.rotation = target


func _build() -> void:
	var rows := ceili(trades.size() / float(columns))
	var width := columns * CUBBY.x + (columns + 1) * BOARD
	var height := rows * CUBBY.y + (rows + 1) * BOARD
	var wood := _material(Color(0.48, 0.34, 0.20))
	var inside := _material(Color(0.30, 0.21, 0.12))
	var flap_mat := _material(Color(0.44, 0.31, 0.18))
	var top := BASE_HEIGHT + height

	# The cupboard it sits on, and the carcass.
	_box("Base", Vector3(0, BASE_HEIGHT / 2.0, CUBBY.z / 2.0), Vector3(width, BASE_HEIGHT, CUBBY.z + 0.04), wood, true)
	_box("Back", Vector3(0, BASE_HEIGHT + height / 2.0, BOARD / 2.0), Vector3(width, height, BOARD), inside, true)
	for c in columns + 1:
		var x := -width / 2.0 + BOARD / 2.0 + c * (CUBBY.x + BOARD)
		_box("Divider_%d" % c, Vector3(x, BASE_HEIGHT + height / 2.0, CUBBY.z / 2.0), Vector3(BOARD, height, CUBBY.z), wood)
	for r in rows + 1:
		var y := top - BOARD / 2.0 - r * (CUBBY.y + BOARD)
		_box("Shelf_%d" % r, Vector3(0, y, CUBBY.z / 2.0), Vector3(width, BOARD, CUBBY.z), wood)

	for i in trades.size():
		var r := i / columns
		var c := i % columns
		var x := -width / 2.0 + BOARD + CUBBY.x / 2.0 + c * (CUBBY.x + BOARD)
		var floor_y := top - BOARD - (r + 1) * CUBBY.y - r * BOARD
		var cubby := Node3D.new()
		cubby.name = "Hole_%s" % trades[i]
		cubby.position = Vector3(x, floor_y, CUBBY.z / 2.0 + 0.01)
		add_child(cubby)
		var contents := Node3D.new()
		contents.name = "Contents"
		cubby.add_child(contents)
		var hole := PigeonHole.new()
		hole.name = "Interactable"
		hole.trade = trades[i]
		hole.label_text = labels[i] if i < labels.size() else String(trades[i]).to_upper()
		hole.display_name = hole.label_text
		hole.object_id = StringName("pigeon_hole_%s" % trades[i])
		hole.contents = contents
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(CUBBY.x - 0.02, CUBBY.y - 0.02, 0.12)
		shape.position = Vector3(0, CUBBY.y / 2.0, CUBBY.z / 2.0 - 0.06)
		hole.add_child(shape)
		cubby.add_child(hole)
		holes[trades[i]] = hole
		_label(hole.label_text, i, Vector3(x, floor_y + CUBBY.y - FASCIA / 2.0, CUBBY.z + 0.03))  # clear of the fascia, which vertex-snaps

	# A painted fascia over each row of mouths, and under it a flap hinged to
	# drop over the row.
	for r in rows:
		var row_top := top - BOARD - r * (CUBBY.y + BOARD)
		_box("Fascia_%d" % r, Vector3(0, row_top - FASCIA / 2.0, CUBBY.z + 0.006), Vector3(width, FASCIA, 0.012), wood)
		var hinge := Node3D.new()
		hinge.name = "FlapHinge_%d" % r
		hinge.position = Vector3(0, row_top - FASCIA, CUBBY.z + 0.004)
		add_child(hinge)
		var flap := MeshInstance3D.new()
		flap.name = "Flap"
		flap.mesh = BoxMesh.new()
		(flap.mesh as BoxMesh).size = Vector3(width - 0.01, CUBBY.y - FASCIA, 0.008)
		flap.position = Vector3(0, -(CUBBY.y - FASCIA) / 2.0, 0)
		flap.material_override = flap_mat
		hinge.add_child(flap)
		_flaps.append(hinge)


func _label(text: String, i: int, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Label_%d" % i
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.0011
	label.width = 240.0
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.outline_size = 0
	# Faded white paint, each hand-lettered slightly differently.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	label.modulate = Color(0.86, 0.83, 0.74).lerp(Color(0.48, 0.34, 0.20), rng.randf_range(0.2, 0.4))
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.rotation.z = deg_to_rad(rng.randf_range(-2.5, 2.5))
	label.position = at
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(label)


func _box(n: String, centre: Vector3, size: Vector3, mat: Material, solid := false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = n
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	mesh.position = centre
	mesh.material_override = mat
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.name = n + "Body"
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = size
		body.position = centre
		body.add_child(shape)
		add_child(body)


func _material(colour: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mat.set_shader_parameter(&"albedo", colour)
	return mat
