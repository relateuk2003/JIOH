# tests/gpu/VideoCompositeProbe.gd — JIOH-42 spike, the riskiest item: does a
# Theora VideoStreamPlayer composite correctly with the low-res 3D viewport
# on the Compatibility renderer, and pass through the same post-processing?
# Two cases: video as a 2D overlay inside the internal viewport (the FMV
# player, JIOH-52), and video on a 3D surface (a CRT or TV in the office).
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const ROOM := preload("res://tools/affine_test_room.tscn")
const VIDEO := preload("res://tests/fixtures/video/test_pattern.ogv")
const PS1 := preload("res://shaders/ps1_standard.gdshader")


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)
	var stack: Control = STACK.instantiate()
	stack.world_scene = ROOM
	add_child(stack)
	var vp: InternalViewport = stack.viewport
	var room: Node3D = vp.get_child(0)
	room.pan = false
	await _frames(4)
	var before := _grab()

	# Case 1: video on a quad in the 3D world.
	var tv_player := VideoStreamPlayer.new()
	tv_player.stream = VIDEO
	tv_player.visible = false  # decodes to a texture; not drawn as a Control
	room.add_child(tv_player)
	tv_player.play()
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.6, 1.2)
	var mat := ShaderMaterial.new()
	mat.shader = PS1
	mat.set_shader_parameter(&"affine_strength", 0.0)
	quad.mesh = mesh
	quad.material_override = mat
	quad.position = Vector3(0, 1.4, -2.0)
	room.add_child(quad)
	await _frames(20)
	mat.set_shader_parameter(&"albedo_texture", tv_player.get_video_texture())
	await _frames(10)
	var tv := _grab()
	check(tv_player.is_playing(), "Theora stream plays on the Compatibility renderer")
	check(_saturation(tv, Rect2i(560, 300, 160, 120)) > _saturation(before, Rect2i(560, 300, 160, 120)) + 0.1,
		"video texture shows on a 3D surface inside the low-res viewport")
	check(_all_levels(tv, 32), "the 3D video surface goes through quantisation with everything else")
	check(_blocks_are_square(tv, 4), "the 3D video surface is drawn at internal resolution")
	quad.queue_free()
	tv_player.queue_free()

	# Case 2: full-frame FMV overlay inside the internal viewport.
	var fmv := VideoStreamPlayer.new()
	fmv.stream = VIDEO
	fmv.size = Vector2(320, 240)
	vp.add_child(fmv)
	fmv.play()
	await _frames(20)
	var overlay := _grab()
	check(_saturation(overlay, Rect2i(0, 0, 1280, 960)) > 0.3, "FMV overlay composites over the 3D scene")
	check(_all_levels(overlay, 32), "the FMV overlay is quantised and dithered like the world")
	check(_blocks_are_square(overlay, 4), "the FMV overlay is drawn at internal resolution")
	overlay.save_png("user://video_composite.png")
	finish()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _grab() -> Image:
	var img := get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _saturation(img: Image, r: Rect2i) -> float:
	var total := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 8):
		for x in range(r.position.x, r.end.x, 8):
			total += img.get_pixel(x, y).s
			n += 1
	return total / n


func _all_levels(img: Image, levels: int) -> bool:
	var allowed := {}
	for k in levels:
		allowed[roundi(k * 255.0 / (levels - 1))] = true
	var data := img.get_data()
	for i in range(0, data.size(), 7):
		if not allowed.has(data[i]):
			return false
	return true


func _blocks_are_square(img: Image, factor: int) -> bool:
	for sample in [Vector2i(10, 10), Vector2i(160, 120), Vector2i(300, 200), Vector2i(150, 100)]:
		var c := img.get_pixelv(sample * factor)
		for dy in factor:
			for dx in factor:
				if img.get_pixelv(sample * factor + Vector2i(dx, dy)) != c:
					return false
	return true
