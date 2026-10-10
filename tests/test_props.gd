# tests/test_props.gd — builds stand-in props for probes: a box mesh with an
# Interactable and, optionally, a PersistentObject.
class_name TestProps

const PS1 := preload("res://shaders/ps1_standard.gdshader")


static func prop(parent: Node, id: String, at: Vector3, tags: Array[StringName],
		verbs: int, persistent := false) -> Interactable:
	var body := _body(parent, id, at, persistent)
	var it := Interactable.new()
	_finish(body, it, id, tags, verbs)
	return it


static func receiver(parent: Node, id: String, at: Vector3, accepts: Array[StringName],
		consume: bool, persistent := false, pickable := false) -> InsertReceiver:
	var body := _body(parent, id, at, persistent)
	var r := InsertReceiver.new()
	r.accepted_tags = accepts
	r.consume = consume
	_finish(body, r, id, [StringName(id)], Interactable.Verb.INSERT | (Interactable.Verb.PICK_UP if pickable else 0))
	return r


static func _body(parent: Node, id: String, at: Vector3, persistent: bool) -> Node3D:
	var body := Node3D.new()
	body.name = id
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.3, 0.05, 0.22)
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mesh.material_override = mat
	body.add_child(mesh)
	if persistent:
		var p := PersistentObject.new()
		p.name = "PersistentObject"
		p.persistent_id = StringName(id)
		body.add_child(p)
	parent.add_child(body)
	body.position = at  # parents in these probes sit at the origin
	return body


static func _finish(body: Node3D, it: Interactable, id: String, tags: Array[StringName], verbs: int) -> void:
	it.name = "Interactable"
	it.object_id = StringName(id)
	it.tags = tags
	it.verbs = verbs
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.3, 0.1, 0.22)
	it.add_child(shape)
	body.add_child(it)
