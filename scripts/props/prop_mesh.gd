# scripts/props/prop_mesh.gd — grey-box geometry for props that build their
# own blockout meshes until they are dressed. Every surface uses the PS1
# standard shader so props sit in the look like the rest of the office.
class_name PropMesh

const PS1 := preload("res://shaders/ps1_standard.gdshader")


static func material(colour: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mat.set_shader_parameter(&"albedo", colour)
	return mat


static func box(parent: Node, n: String, centre: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = n
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	mesh.position = centre
	mesh.material_override = material(colour)
	parent.add_child(mesh)
	return mesh


## An Area3D interactable with a box shape, added under parent.
static func handle(parent: Node, it: Interactable, n: String, centre: Vector3, size: Vector3) -> Interactable:
	it.name = n
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	shape.position = centre
	it.add_child(shape)
	parent.add_child(it)
	return it


## Small printed or painted lettering, read by looking closely: a bitmap
## decal (JIOH-63), sized from the old Label3D font size so layouts hold.
static func label(parent: Node, n: String, text: String, at: Vector3, size := 24,
		paper := Color(0.9, 0.88, 0.8), ink := Color(0.08, 0.08, 0.08)) -> PixelDecal:
	var d := PixelDecal.make(text, ink, paper, size * 0.0006 / JiohFonts.NATIVE[JiohFonts.Face.BODY])
	d.name = n
	d.position = at
	parent.add_child(d)
	return d
