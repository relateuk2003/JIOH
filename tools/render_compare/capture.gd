# tools/render_compare/capture.gd — JIOH-59: renders the render stack with a
# world scene and saves the window to a PNG. Needs a real display (or Xvfb).
#
#   godot --path . --rendering-driver opengl3 --script res://tools/render_compare/capture.gd \
#       -- --out=user://shot.png [--world=res://tools/affine_test_room.tscn] \
#          [--size=1280x960] [--frames=10] [--set=snap_enabled:false]
extends SceneTree

const STACK := "res://scenes/rendering/render_stack.tscn"


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := {}
	var sets: Array[String] = []
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "set":
			sets.append(kv[1])
		else:
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var size_parts := String(args.get("size", "1280x960")).split("x")
	root.size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	var stack: Node = (load(STACK) as PackedScene).instantiate()
	if args.has("world"):
		stack.world_scene = load(args.world)
	root.add_child(stack)
	var world := stack.get_node("InternalViewport").get_child(0)
	if "pan" in world:
		world.pan = false
	var config := root.get_node("RenderConfig")
	for s in sets:
		var kv := s.split(":", true, 1)
		config.set_value(StringName(kv[0]), str_to_var(kv[1]))
	for i in int(args.get("frames", "10")):
		await process_frame
	var img := root.get_texture().get_image()
	var out := String(args.get("out", "user://shot.png"))
	img.save_png(out)
	print("CAPTURED %s %s" % [out, img.get_size()])
	quit()
