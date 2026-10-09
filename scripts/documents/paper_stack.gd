# scripts/documents/paper_stack.gd — JIOH-32: sheets held together as one
# thing you carry. A pack is a stack; a single sheet is a stack of one. The
# stack keeps its order, top sheet first.
class_name PaperStack
extends Node3D

const SHEET := Vector2(0.21, 0.297)  # A4, metres
const SHEET_THICKNESS := 0.0012
const PS1 := preload("res://shaders/ps1_standard.gdshader")

var documents: Array[DocumentInstance] = []
var interactable: PaperStackHandle
var _mesh: MeshInstance3D


## A stack of the given sheets, ready to be added to the scene.
static func make(docs: Array[DocumentInstance]) -> PaperStack:
	var s := PaperStack.new()
	s.name = "PaperStack"
	s._mesh = MeshInstance3D.new()
	s._mesh.mesh = BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mat.set_shader_parameter(&"albedo", Color(0.93, 0.92, 0.86))
	s._mesh.material_override = mat
	s.add_child(s._mesh)
	var it := PaperStackHandle.new()
	it.name = "Interactable"
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	it.add_child(shape)
	s.add_child(it)
	s.interactable = it
	s.add(docs)
	return s


## The sheet facing up.
func top() -> DocumentInstance:
	return documents[0] if not documents.is_empty() else null


## Lays another stack on top of this one; the other node goes away.
func put_on_top(other: PaperStack) -> void:
	var docs := other.documents.duplicate()
	docs.append_array(documents)
	documents.clear()
	other.queue_free()
	add(docs)


## Slides the top sheet to the bottom, as you do working through a pack.
func turn_top_under() -> void:
	if documents.size() > 1:
		documents.append(documents.pop_front())
	interactable.object_id = documents[0].instance_id


## Puts more sheets on the bottom of the stack.
func add(docs: Array[DocumentInstance]) -> void:
	documents.append_array(docs)
	var h := maxf(SHEET_THICKNESS * documents.size(), 0.003)
	(_mesh.mesh as BoxMesh).size = Vector3(SHEET.x, h, SHEET.y)
	_mesh.position.y = h / 2.0
	var shape := interactable.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size = Vector3(SHEET.x, maxf(h, 0.03), SHEET.y)
	shape.position.y = maxf(h, 0.03) / 2.0
	interactable.object_id = documents[0].instance_id if not documents.is_empty() else &"paper_stack"
