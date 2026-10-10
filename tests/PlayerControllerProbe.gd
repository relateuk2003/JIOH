# tests/PlayerControllerProbe.gd — JIOH-46 and the JIOH-43 route timings.
# Drives the real controller through physics in the real blockout. Run with
# --fixed-fps 60 so simulated time does not depend on machine speed:
#   godot --headless --fixed-fps 60 --path . res://tests/PlayerControllerProbe.tscn
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var player: PlayerController
var steps := 0


func _ready() -> void:
	CampaignState.slot = TEST_SLOT
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	player.footstep.connect(func(_s): steps += 1)
	await _physics(5)

	# Constant 1.6 m/s after the ramp, along the corridor.
	_teleport(Vector3(17.0, 0, 6.5), Vector3(1, 0, 0))
	await _physics(5)
	player.scripted_input = Vector2(0, -1)
	await _physics(30)
	var start := player.global_position
	await _physics(600)
	var speed := player.global_position.distance_to(start) / 10.0
	check(absf(speed - 1.6) < 0.01, "walk speed is a constant 1.6 m/s over ten seconds (got %.3f)" % speed)
	player.scripted_input = Vector2(1, -1)
	await _physics(60)
	var diag := Vector2(player.velocity.x, player.velocity.z).length()
	check(diag <= 1.6 + 0.001, "diagonal input is no faster (%.3f m/s)" % diag)
	check(not InputMap.has_action(&"sprint") and not InputMap.has_action(&"run"), "there is no sprint action")

	# Releasing stops the bob where it is; standing still is perfectly still.
	player.scripted_input = Vector2.ZERO
	await _physics(30)
	var head_after_stop := player.head.position
	await _physics(60)
	check(player.head.position == head_after_stop, "the camera is perfectly static when standing still")
	check(not is_equal_approx(head_after_stop.y, player.profile.eye_height) or not is_equal_approx(head_after_stop.x, 0.0),
		"the bob halts mid-stride rather than easing back to centre")

	# Raw mouse look: the same motion gives the same yaw however it is split
	# across frames.
	var yaw0 := player.rotation.y
	player.look(Vector2(120, 0))
	var one_shot := player.rotation.y - yaw0
	player.rotation.y = yaw0
	for i in 12:
		player.look(Vector2(10, 0))
	check(is_equal_approx(player.rotation.y - yaw0, one_shot), "mouse look is identical at any frame split")
	player.look(Vector2(0, -100000))
	check(is_equal_approx(rad_to_deg(player.head.rotation.x), 80.0), "pitch is clamped at 80 degrees")
	player.head.rotation.x = 0

	# Bob amplitude 0: no bob, same footstep cadence.
	var with_bob := await _walk_and_count(0.035)
	var without := await _walk_and_count(0.0)
	check(with_bob == without and with_bob > 0, "footsteps keep the same cadence with the bob off (%d vs %d)" % [with_bob, without])
	check(is_equal_approx(player.head.position.y, player.profile.eye_height) and is_zero_approx(player.head.position.x),
		"bob amplitude 0 means no visual bob")
	player.profile.bob_amplitude = 0.035

	# Locked movement: no motion, look still live.
	_teleport(Vector3(17.0, 0, 6.5), Vector3(1, 0, 0))
	await _physics(5)
	player.set_movement_locked(true)
	player.scripted_input = Vector2(0, -1)
	var at := player.global_position
	await _physics(60)
	check(player.global_position.distance_to(at) < 0.001, "locked movement does not move the body")
	var y := player.rotation.y
	player.look(Vector2(50, 0))
	check(player.rotation.y != y, "mouse look still responds while locked")
	player.set_movement_locked(false)
	player.scripted_input = null

	# Route timings in the blockout (JIOH-43 targets).
	var routes: Node = level.office.get_node("Routes")
	var targets := {
		"DeskToHatch": Vector2(0, 5), "DeskToFileStore": Vector2(8, 10),
		"DeskToPrintRoom": Vector2(12, 15), "DeskToKitchen": Vector2(20, 999),
	}
	for route in targets:
		var t := await _walk_route((routes.get_node(route) as Path3D).curve)
		var r: Vector2 = targets[route]
		check(t >= r.x and t <= r.y, "%s takes %.1f s (target %s-%s s)" % [route, t, r.x, r.y if r.y < 999 else "+"])
	var yard := await _walk_route((routes.get_node("YardToHatch") as Path3D).curve)
	check(yard > 0, "yard door to hatch is walkable with no dead ends (%.1f s)" % yard)
	finish()


func _walk_and_count(amplitude: float) -> int:
	player.profile.bob_amplitude = amplitude
	_teleport(Vector3(17.0, 0, 6.5), Vector3(1, 0, 0))
	await _physics(5)
	player.stride_distance = 0.0
	steps = 0
	player.scripted_input = Vector2(0, -1)
	await _physics(300)
	player.scripted_input = Vector2.ZERO
	await _physics(30)
	return steps


## Walks a route waypoint to waypoint; returns seconds, or -1 if stuck.
func _walk_route(curve: Curve3D) -> float:
	_teleport(curve.get_point_position(0), Vector3(1, 0, 0))
	await _physics(5)
	var frames := 0
	for i in range(1, curve.point_count):
		var goal := curve.get_point_position(i)
		var last_progress := frames
		var best := INF
		while true:
			var to := goal - player.global_position
			to.y = 0
			if to.length() < 0.1:
				break
			player.rotation.y = atan2(-to.x, -to.z)
			player.scripted_input = Vector2(0, -1)
			await get_tree().physics_frame
			frames += 1
			if to.length() < best - 0.01:
				best = to.length()
				last_progress = frames
			if frames - last_progress > 120:
				player.scripted_input = null
				return -1.0
	player.scripted_input = null
	return frames / float(Engine.physics_ticks_per_second)


func _teleport(at: Vector3, facing: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = atan2(-facing.x, -facing.z)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
