# tests/RenderConfigProbe.gd — JIOH-44 / JIOH-55 / JIOH-59 checks that need no GPU.
extends Probe


func _ready() -> void:
	# Integer scale maths (JIOH-44).
	var s := InternalViewport.integer_scale
	check(s.call(Vector2i(1280, 960), Vector2i(320, 240)) == 4, "1280x960 is exactly 4x")
	check(s.call(Vector2i(1600, 900), Vector2i(320, 240)) == 3, "1600x900 is 3x")
	check(s.call(Vector2i(3440, 1440), Vector2i(320, 240)) == 6, "3440x1440 is 6x")
	check(s.call(Vector2i(200, 100), Vector2i(320, 240)) == 1, "never below 1x")
	check(InternalViewport.display_origin(Vector2i(1600, 900), Vector2i(320, 240), 3) == Vector2i(320, 90),
		"1600x900 is centred with integer offsets")

	# RenderConfig loads the shipped preset (JIOH-59).
	var shipped_path := RenderConfig.SHIPPED_PATH
	var before := FileAccess.get_md5(shipped_path)
	check(RenderConfig.master != null and RenderConfig.master.snap_resolution == Vector2(160, 120),
		"RenderConfig boots from the shipped preset")

	# Fog colour is the clear colour (JIOH-55).
	var env := RenderConfig.environment
	check(env.fog_light_color == env.background_color and env.background_color == RenderConfig.master.fog_colour,
		"fog colour and clear colour are identical")
	var far := RenderConfig.master.far_plane()
	check(exp(-RenderConfig.master.fog_density * far) < 1.0 / 256.0, "fog saturates before the far plane (%.1fm)" % far)

	# Toggling one effect leaves the rest alone, and nothing is written to disk.
	# (Global shader parameters cannot be read back headless; the GPU probe
	# checks their effect on real pixels.)
	var changed: Array[StringName] = []
	RenderConfig.config_changed.connect(func(p): changed.append(p))
	RenderConfig.set_value(&"snap_enabled", false)
	var m := RenderConfig.master
	check(not m.snap_enabled and changed == [&"snap_enabled"], "snap toggles off and announces only itself")
	check(m.affine_enabled and m.dither_enabled and env.fog_enabled,
		"affine, dither and fog unaffected by the snap toggle")
	RenderConfig.set_value(&"fog_density", 0.3)
	check(is_equal_approx(env.fog_density, 0.3), "fog density reaches the environment")
	check(FileAccess.get_md5(shipped_path) == before, "the shipped preset on disk is unmodified")
	RenderConfig.restore_shipped()
	check(RenderConfig.master.snap_enabled and is_equal_approx(env.fog_density, 0.12),
		"restore shipped preset returns every value")

	finish()
