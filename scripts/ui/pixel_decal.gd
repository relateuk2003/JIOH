# scripts/ui/pixel_decal.gd — JIOH-63: painted or printed lettering on an
# object. Replaces Label3D, which antialiases and scales continuously: the
# words are drawn by a PixelText into a SubViewport at one texel per glyph
# pixel and shown on a quad with the readable PS1 material (no affine warp).
# Faces local +Z like a Label3D, centred on its origin.
class_name PixelDecal
extends Node3D

const READABLE := preload("res://resources/materials/ps1_readable_material.tres")

@export var text: String = "":
	set(v):
		text = v
		_rebuild()
@export var face: JiohFonts.Face = JiohFonts.Face.BODY
@export var ink: Color = Color(0.08, 0.08, 0.08)
## The surface the lettering is on; the decal is opaque, so it matches it.
@export var paper: Color = Color(0.9, 0.88, 0.8)
## Metres per glyph pixel.
@export var texel_m: float = 0.002

var label: PixelText
var _viewport: SubViewport
var _mesh: MeshInstance3D


static func make(t: String, ink_colour: Color, paper_colour: Color, texel: float,
		f: JiohFonts.Face = JiohFonts.Face.BODY) -> PixelDecal:
	var d := PixelDecal.new()
	d.face = f
	d.ink = ink_colour
	d.paper = paper_colour
	d.texel_m = texel
	d.text = t
	return d


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.transparent_bg = false
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(_viewport)
		var bg := ColorRect.new()
		bg.name = "Paper"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_viewport.add_child(bg)
		label = PixelText.new()
		label.position = Vector2(1, 0)
		_viewport.add_child(label)
		_mesh = MeshInstance3D.new()
		_mesh.name = "Decal"
		_mesh.mesh = QuadMesh.new()
		var mat := READABLE.duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"albedo_texture", _viewport.get_texture())
		_mesh.material_override = mat
		add_child(_mesh)
	(_viewport.get_node("Paper") as ColorRect).color = paper
	label.face = face
	label.ink = ink
	label.text = text
	var px := Vector2i(ceili(JiohFonts.width_of(text, face)) + 2, JiohFonts.NATIVE[face])
	px.x = maxi(px.x, 2)
	_viewport.size = px
	(_mesh.mesh as QuadMesh).size = Vector2(px) * texel_m
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mesh.visible = text != ""


## The decal as drawn, for tests.
func image() -> Image:
	return _viewport.get_texture().get_image()
