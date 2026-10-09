# tests/InteractionProbe.gd — JIOH-50 acceptance criteria, in the blockout.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const PS1 := preload("res://shaders/ps1_standard.gdshader")

var level: Node3D
var player: PlayerController
var props: Node3D
var targets: Array = []
var performed: Array = []
var refused: Array = []
var carries: Array = []


func _ready() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	props = level.get_node("Props")
	var im := InteractionManager
	im.target_changed.connect(func(_a, b): targets.append(b))
	im.interaction_performed.connect(func(i, v): performed.append([i.object_id, v]))
	im.interaction_refused.connect(func(i, r): refused.append([i.object_id, r]))
	im.carry_changed.connect(func(i): carries.append(i))

	# A bench in the corridor with things on it.
	var folder := _prop("folder", Vector3(20.0, 0.8, 5.9), [&"folder"], Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE)
	var paper := _prop("paper", Vector3(20.6, 0.8, 5.9), [&"paper"], Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE)
	var key := _prop("key", Vector3(21.2, 0.8, 5.9), [&"key"], Interactable.Verb.PICK_UP)
	var sheet := _prop("job_sheet", Vector3(21.8, 0.8, 5.9), [&"form"], Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE)
	var tray := _receiver("printer_tray", Vector3(22.4, 0.8, 5.9), [&"paper"], true)
	await _physics(4)

	# Looking at an object within reach highlights it; target_changed once.
	_stand_and_look(Vector3(20.0, 0, 6.9), folder)
	targets.clear()
	await _physics(3)
	check(im.target == folder, "the folder becomes the target within two metres")
	check(targets.count(folder) == 1, "target_changed fired exactly once for it (got %d)" % targets.count(folder))
	check(_highlight(folder) == 1.0, "the target carries the highlight")
	_stand_and_look(Vector3(20.0, 0, 9.5 - 0.0), folder)  # too far
	player.global_position = Vector3(20.0, 0, 6.9) + Vector3(0, 0, 2.5)
	await _physics(3)
	check(im.target == null and _highlight(folder) == 0.0, "out of reach: no target, highlight removed")

	# Pick up the folder; a second pick-up is refused for full hands.
	_stand_and_look(Vector3(20.0, 0, 6.9), folder)
	await _physics(3)
	im.use()
	check(im.carried_item == folder and carries.back() == folder, "the folder is picked up")
	_stand_and_look(Vector3(20.6, 0, 6.9), paper)
	await _physics(3)
	refused.clear()
	im.use()
	check(im.carried_item == folder and refused.size() == 1 and refused[0][1] == "hands_full",
		"a second pick-up is refused because the hands are full")
	# Put the folder down on the floor.
	player.head.rotation.x = deg_to_rad(-60)
	await _physics(3)
	im.use()
	check(im.carried_item == null and folder.body().get_parent() == props, "the folder is placed under Props")
	player.head.rotation.x = 0

	# Paper into the printer tray: consumed, carry_changed(null).
	_stand_and_look(Vector3(20.6, 0, 6.9), paper)
	await _physics(3)
	im.use()
	_stand_and_look(Vector3(22.4, 0, 6.9), tray)
	await _physics(3)
	carries.clear()
	im.use()
	await get_tree().process_frame
	check(not is_instance_valid(paper) and im.carried_item == null, "the paper is consumed by the tray")
	check(carries == [null], "carry_changed fired with null")

	# A key into the tray: refused with a specific reason, key still held.
	_stand_and_look(Vector3(21.2, 0, 6.9), key)
	await _physics(3)
	im.use()
	_stand_and_look(Vector3(22.4, 0, 6.9), tray)
	await _physics(3)
	refused.clear()
	im.use()
	check(refused.size() == 1 and refused[0][1] == "printer_tray_takes_only_paper",
		"the key is refused with a specific reason (%s)" % [refused])
	check(im.carried_item == key, "the key stays in the player's hands")
	player.global_position = Vector3(23.5, 0, 6.9)
	player.head.rotation.x = deg_to_rad(-60)
	await _physics(3)
	im.use()  # put it down
	player.head.rotation.x = 0

	# Examine a job sheet, then exit: exact transform and parent restored.
	_stand_and_look(Vector3(21.8, 0, 6.9), sheet)
	await _physics(3)
	var parent_before := sheet.body().get_parent()
	var xform_before := sheet.body().transform
	im.examine()
	check(im.examined_item == sheet and player.movement_locked, "examine locks movement and holds the sheet up")
	im.rotate_examined(Vector2(40, 15))
	im.examine()
	check(sheet.body().get_parent() == parent_before and sheet.body().transform == xform_before,
		"exiting examine restores the exact parent and transform")
	check(not player.movement_locked, "movement is unlocked after examine")

	# Janice's desk refuses.
	var janice := level.office.get_node("JanicesDesk/Interactable") as Interactable
	refused.clear()
	im.perform(janice, Interactable.Verb.OPEN)
	check(refused.size() == 1 and refused[0][1] == "janices_desk_not_yours", "Janice's desk returns a refusal")

	# Every event carries an object id and a verb.
	var ok := performed.size() >= 5
	for e in performed:
		ok = ok and e[0] != &"" and e[1] in [1, 2, 4, 8, 16]
	check(ok, "every performed event carries the object id and verb (%d events)" % performed.size())
	finish()


func _prop(id: String, at: Vector3, tags: Array[StringName], verbs: int) -> Interactable:
	var body := Node3D.new()
	body.name = id
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.3, 0.05, 0.22)
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mesh.material_override = mat
	body.add_child(mesh)
	var it := Interactable.new()
	it.name = "Interactable"
	it.object_id = StringName(id)
	it.tags = tags
	it.verbs = verbs
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.3, 0.1, 0.22)
	it.add_child(shape)
	body.add_child(it)
	props.add_child(body)
	body.global_position = at
	return it


func _receiver(id: String, at: Vector3, accepts: Array[StringName], consume: bool) -> InsertReceiver:
	var body := Node3D.new()
	body.name = id
	var r := InsertReceiver.new()
	r.name = "Interactable"
	r.object_id = StringName(id)
	r.accepted_tags = accepts
	r.consume = consume
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.4, 0.2, 0.3)
	r.add_child(shape)
	body.add_child(r)
	props.add_child(body)
	body.global_position = at
	return r


func _stand_and_look(at: Vector3, thing: Interactable) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = at
	var eye := at + Vector3(0, player.profile.eye_height, 0)
	var to := thing.global_position - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _highlight(it: Interactable) -> float:
	var mesh := it.body().get_child(0) as GeometryInstance3D
	return float(mesh.get_instance_shader_parameter(&"highlight"))


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
