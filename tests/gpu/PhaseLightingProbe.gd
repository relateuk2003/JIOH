# tests/gpu/PhaseLightingProbe.gd — JIOH-84: six lighting states, told apart
# by the light alone. Renders the office from Janice's desk in each phase.
# Set JIOH_SCREEN_DIR to keep the six frames.
extends Probe

const STACK := preload("res://scenes/rendering/render_stack.tscn")
const LEVEL := preload("res://scenes/levels/office_level.tscn")
const P := DayPhase.Phase
const TIMES := [[P.CLOSED, 5, 0], [P.PRE_OPEN, 7, 0], [P.HANDOUT, 8, 30],
	[P.WORKING, 12, 30], [P.CUTOFF, 16, 0], [P.WIND_DOWN, 17, 15]]


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 960)
	use_fake_clock(WED_2026_10_07, 5, 0)
	CampaignState.new_campaign()
	var stack: Control = STACK.instantiate()
	stack.world_scene = LEVEL
	add_child(stack)
	for i in 4:
		await RenderingServer.frame_post_draw
	var level: Node = stack.viewport.get_child(0)
	var dressing: PhaseDressing = level.get_node("PhaseDressing")
	# Face the room from the desk, looking across reception to the windows.
	level.player.rotation.y = deg_to_rad(-60.0)
	level.player.head.rotation.x = deg_to_rad(-5.0)
	var means := {}
	var dir := OS.get_environment("JIOH_SCREEN_DIR")
	for t in TIMES:
		set_local(WED_2026_10_07, t[1], t[2])
		var wait := 0
		while (dressing.applied != t[0] or dressing._tween and dressing._tween.is_running()) and wait < 600:
			await RenderingServer.frame_post_draw
			wait += 1
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := get_tree().root.get_texture().get_image()
		if dir != "":
			img.save_png(dir.path_join("phase-%d-%s.png" % [t[0], DayPhase.phase_name(t[0])]))
		means[t[0]] = _mean(img)
		print("  %s: mean %s" % [DayPhase.phase_name(t[0]), means[t[0]]])
	var closest := INF
	for a in means:
		for b in means:
			if a < b:
				closest = minf(closest, Vector3(means[a].r, means[a].g, means[a].b).distance_to(Vector3(means[b].r, means[b].g, means[b].b)))
	check(closest > 0.01, "every phase looks different from every other (closest pair %.3f apart)" % closest)
	var lum := func(c: Color): return c.get_luminance()
	check(lum.call(means[P.CLOSED]) < lum.call(means[P.HANDOUT]) and lum.call(means[P.PRE_OPEN]) < lum.call(means[P.WORKING]),
		"before opening the room is darker than when the tubes are on")
	var warmth := func(c: Color): return c.r / maxf(c.b, 0.001)
	check(warmth.call(means[P.WIND_DOWN]) > warmth.call(means[P.WORKING]) and warmth.call(means[P.WORKING]) > warmth.call(means[P.CLOSED]),
		"wind-down is the warmest light, night the coldest")
	finish()


func _mean(img: Image) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum /= n
	return Color(sum.x, sum.y, sum.z)
