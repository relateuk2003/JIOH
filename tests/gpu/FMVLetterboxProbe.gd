# tests/gpu/FMVLetterboxProbe.gd — JIOH-52: the letterbox on real pixels.
# The bars are drawn at 320x240 and scaled with the picture, so at 4x every
# bar edge falls on a 4-pixel boundary and the bars are pure black.
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const ROOM := preload("res://tools/affine_test_room.tscn")


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)
	var stack: Control = STACK.instantiate()
	stack.world_scene = ROOM
	add_child(stack)
	await _frames(4)
	var fmv := FMVPlayer.spawn(stack.viewport.get_child(0))
	fmv.play("res://tests/fixtures/video/wide_pattern.ogv", true)
	await _frames(20)
	var img := get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var out := OS.get_environment("JIOH_SCREEN")
	if out != "":
		img.save_png(out)
	check(_black(img, Rect2i(0, 0, 1280, 120)) and _black(img, Rect2i(0, 840, 1280, 120)), "30px bars top and bottom are pure black")
	check(not _black(img, Rect2i(0, 120, 1280, 4)) and not _black(img, Rect2i(0, 836, 1280, 4)), "the picture starts on the very next internal row")
	var crisp := true
	for x in range(0, 1280, 7):
		var c := img.get_pixel(x, 120)
		for y in range(121, 124):
			crisp = crisp and img.get_pixel(x, y) == c
	check(crisp, "the bar edge is one internal pixel scaled 4x, not smeared")
	fmv.stop()
	finish()


func _black(img: Image, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y, 3):
		for x in range(r.position.x, r.end.x, 5):
			var c := img.get_pixel(x, y)
			if c.r > 0.03 or c.g > 0.03 or c.b > 0.03:
				return false
	return true


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
