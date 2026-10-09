# tests/gpu/RenderPixelsProbe.gd — JIOH-44 / JIOH-55 / JIOH-59 checks on real
# pixels. Needs a GPU or Xvfb (tests/run_all.sh uses xvfb-run when present):
#   godot --path . --rendering-driver opengl3 res://tests/gpu/RenderPixelsProbe.tscn
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const ROOM := preload("res://tools/affine_test_room.tscn")

var stack: Control
var resizes := 0


func _ready() -> void:
	var window := get_tree().root
	window.size = Vector2i(1280, 960)
	stack = STACK.instantiate()
	stack.world_scene = ROOM
	add_child(stack)
	stack.get_node("InternalViewport").get_child(0).pan = false
	stack.viewport.resolution_changed.connect(func(_s, _f): resizes += 1)
	await _frames(6)

	var boot := _grab()
	check(stack.viewport.size == Vector2i(320, 240), "world renders into a 320x240 viewport")
	check(stack.viewport.scale_factor == 4 and _border_is(boot, Color.BLACK) == false,
		"1280x960 is 4x with no borders")
	check(_blocks_are_square(boot, Vector2i(0, 0), 4), "each internal pixel is a 4x4 block of identical pixels")
	check(_all_levels(boot, 32), "every channel of every pixel is one of 32 values")

	var again := _grab()
	check(boot.get_data() == again.get_data(), "a still frame is identical frame to frame (no dither crawl)")

	RenderConfig.set_value(&"dither_enabled", false)
	await _frames(3)
	check(_all_levels(_grab(), 32), "dither off still quantises to 32 levels")
	RenderConfig.set_value(&"snap_enabled", false)
	await _frames(3)
	var unsnapped := _grab()
	check(unsnapped.get_data() != boot.get_data(), "turning snapping off changes the geometry")
	RenderConfig.restore_shipped()
	await _frames(3)
	check(_grab().get_data() == boot.get_data(), "restore shipped preset gives the boot frame back")

	resizes = 0
	window.size = Vector2i(1600, 900)
	await _frames(4)
	var img := _grab()
	check(stack.viewport.scale_factor == 3, "1600x900 is 3x")
	check(resizes == 1, "resolution_changed fired once for the resize (got %d)" % resizes)
	check(img.get_pixel(100, 450) == Color.BLACK and img.get_pixel(800, 40) == Color.BLACK,
		"pillarbox and letterbox are pure black")
	check(_blocks_are_square(img, Vector2i(320, 90), 3), "3x blocks are square and aligned to integer offsets")

	window.size = Vector2i(3440, 1440)
	await _frames(4)
	img = _grab()
	check(stack.viewport.scale_factor == 6 and stack.get_node("Display").position == Vector2(760, 0),
		"ultrawide is centred at 6x")
	check(img.get_pixel(300, 700) == Color.BLACK and img.get_pixel(3200, 700) == Color.BLACK,
		"ultrawide side borders are pure black")
	window.size = Vector2i(1280, 960)
	finish()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _grab() -> Image:
	var img := get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _border_is(img: Image, c: Color) -> bool:
	return img.get_pixel(0, 0) == c and img.get_pixel(img.get_width() - 1, img.get_height() - 1) == c


func _blocks_are_square(img: Image, origin: Vector2i, factor: int) -> bool:
	for sample in [Vector2i(10, 10), Vector2i(160, 120), Vector2i(300, 200), Vector2i(77, 191)]:
		var top_left: Vector2i = origin + sample * factor
		var c := img.get_pixelv(top_left)
		for dy in factor:
			for dx in factor:
				if img.get_pixelv(top_left + Vector2i(dx, dy)) != c:
					return false
	return true


func _all_levels(img: Image, levels: int) -> bool:
	var allowed := {}
	for k in levels:
		allowed[roundi(k * 255.0 / (levels - 1))] = true
	var data := img.get_data()
	for i in range(0, data.size(), 7):
		if not allowed.has(data[i]):
			return false
	return true
