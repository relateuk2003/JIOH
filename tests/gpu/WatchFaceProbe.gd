# tests/gpu/WatchFaceProbe.gd — JIOH-67: the watch face on real pixels, and a
# look at it raised in the office.
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const LEVEL := preload("res://scenes/levels/office_level.tscn")


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)
	use_fake_clock(WED_2026_10_07, 9, 41)
	CampaignState.new_campaign()
	var stack: Control = STACK.instantiate()
	stack.world_scene = LEVEL
	add_child(stack)
	for i in 4:
		await RenderingServer.frame_post_draw
	var level: Node = stack.viewport.get_child(0)
	var watch := level.player.get_node("Head/Eye/Wristwatch") as Wristwatch
	var face := watch.face_image()
	face.convert(Image.FORMAT_RGB8)
	var colours := {}
	for y in face.get_height():
		for x in face.get_width():
			colours[face.get_pixel(x, y).to_rgba32()] = true
	check(colours.size() == 2, "the LCD has two colours, segment and ground (%d)" % colours.size())
	var ink := 0
	for y in face.get_height():
		for x in face.get_width():
			if face.get_pixel(x, y).r < 0.3:
				ink += 1
	check(ink > 60, "and the time is actually drawn on it (%d ink pixels)" % ink)

	var down := _dark_lower_right(get_tree().root.get_texture().get_image())
	watch.press()
	for i in 40:
		await RenderingServer.frame_post_draw
	var shot := get_tree().root.get_texture().get_image()
	var out := OS.get_environment("JIOH_SCREEN")
	if out != "":
		shot.save_png(out)
	var dark := _dark_lower_right(shot)
	check(dark > down + 1500, "raised, the watch fills the lower right of the view (%d dark samples, %d lowered)" % [dark, down])
	watch.release()
	finish()


## Near-black samples in the lower right quarter: the strap and case.
func _dark_lower_right(img: Image) -> int:
	var dark := 0
	for y in range(480, 960, 4):
		for x in range(640, 1280, 4):
			if img.get_pixel(x, y).get_luminance() < 0.12:
				dark += 1
	return dark
