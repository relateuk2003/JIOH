# tests/gpu/ShippedLookProbe.gd — JIOH-59: the screenshot comparison harness.
#
# Renders the affine test room with the shipped preset and diffs it against
# tests/reference/shipped_look.png, so a stray shader edit that changes the
# look fails visibly in review. GPUs and drivers differ slightly, so up to
# 2% of pixels may differ. After a deliberate change to the look, regenerate:
#   JIOH_UPDATE_REFERENCE=1 godot --path . res://tests/gpu/ShippedLookProbe.tscn
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const ROOM := preload("res://tools/affine_test_room.tscn")
const REFERENCE := "res://tests/reference/shipped_look.png"
const TOLERANCE := 0.02


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)
	var stack: Control = STACK.instantiate()
	stack.world_scene = ROOM
	add_child(stack)
	stack.viewport.get_child(0).pan = false
	RenderConfig.restore_shipped()
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)

	if OS.get_environment("JIOH_UPDATE_REFERENCE") == "1":
		img.save_png(ProjectSettings.globalize_path(REFERENCE))
		print("reference written: ", REFERENCE)
		finish()
		return

	var ref := Image.load_from_file(ProjectSettings.globalize_path(REFERENCE))
	if ref == null:
		check(false, "reference image exists (run with JIOH_UPDATE_REFERENCE=1 to create it)")
		finish()
		return
	ref.convert(Image.FORMAT_RGB8)
	check(ref.get_size() == img.get_size(), "capture matches the reference size")
	var a := img.get_data()
	var b := ref.get_data()
	var differing := 0
	for i in range(0, a.size(), 3):
		if a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2]:
			differing += 1
	var fraction := differing / float(a.size() / 3)
	check(fraction <= TOLERANCE, "shipped look matches the reference (%.2f%% of pixels differ)" % (fraction * 100.0))
	if fraction > TOLERANCE:
		img.save_png("user://shipped_look_actual.png")
		print("actual frame saved to user://shipped_look_actual.png")
	finish()
