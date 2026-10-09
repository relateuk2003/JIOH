# scripts/documents/sheet_view.gd — JIOH-23: a sheet of A4 lying face up, its
# face drawn live from a DocumentInstance. Stands in for a template's
# paper_scene until the forms are dressed (JIOH-9). Top of the page is local
# -Z.
class_name SheetView
extends Node3D

const SIZE := Vector2(0.21, 0.297)
const PIXELS := Vector2i(420, 594)
const READABLE := preload("res://resources/materials/ps1_readable_material.tres")

var doc: DocumentInstance
var canvas: SheetCanvas
var _viewport: SubViewport


static func make(d: DocumentInstance) -> SheetView:
	var v := SheetView.new()
	v.name = "Sheet"
	v.doc = d
	return v


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = PIXELS
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	canvas = SheetCanvas.new()
	canvas.size = Vector2(PIXELS)
	canvas.doc = doc
	_viewport.add_child(canvas)
	var mesh := MeshInstance3D.new()
	mesh.name = "Paper"
	mesh.mesh = PlaneMesh.new()
	(mesh.mesh as PlaneMesh).size = SIZE
	var mat := READABLE.duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"albedo_texture", _viewport.get_texture())
	mesh.material_override = mat
	add_child(mesh)


## Redraws the face after anything was written, stamped or punched.
func refresh(live_key: StringName = &"", live_value: Variant = null) -> void:
	if canvas == null:
		return
	canvas.live_key = live_key
	canvas.live_value = live_value
	canvas.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Sheet-space (0..1, top-left origin) of a local point on the paper.
static func uv_of_local(p: Vector3) -> Vector2:
	return Vector2(p.x / SIZE.x + 0.5, p.z / SIZE.y + 0.5)


## Local point on the paper for a sheet-space position.
static func local_of_uv(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * SIZE.x, 0.0, (uv.y - 0.5) * SIZE.y)
