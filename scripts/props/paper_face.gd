# scripts/props/paper_face.gd — a flat face drawn by a script into its own
# SubViewport: a planner, a register page, a drawing, a CRT screen. The
# owner supplies a painter Callable(canvas: Control) and calls refresh()
# whenever what it shows changes. Top of the face is local -Z when flat, or
# local +Y when stood upright (upright = true).
class_name PaperFace
extends Node3D

const READABLE := preload("res://resources/materials/ps1_readable_material.tres")

@export var size_m := Vector2(0.21, 0.297)
@export var pixels := Vector2i(420, 594)
@export var upright := false
## Emissive faces (a CRT) ignore the room's lighting.
@export var glow := false

var painter: Callable
var canvas: FaceCanvas
var _viewport: SubViewport
var _mesh: MeshInstance3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = pixels
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	canvas = FaceCanvas.new()
	canvas.size = Vector2(pixels)
	canvas.face = self
	_viewport.add_child(canvas)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Face"
	var quad := PlaneMesh.new()
	quad.size = size_m
	if upright:
		quad.orientation = PlaneMesh.FACE_Z
	_mesh.mesh = quad
	var mat := READABLE.duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"albedo_texture", _viewport.get_texture())
	_mesh.material_override = mat
	if glow:
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	refresh()


func refresh() -> void:
	if canvas == null:
		return
	canvas.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The rendered face, for tests and screenshots.
func image() -> Image:
	return _viewport.get_texture().get_image()
