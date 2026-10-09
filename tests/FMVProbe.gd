# tests/FMVProbe.gd — JIOH-52 acceptance criteria.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const WIDE := "res://tests/fixtures/video/wide_pattern.ogv"
const SQUARE := "res://tests/fixtures/video/test_pattern.ogv"

var level: Node3D
var player: PlayerController
var phases: Array = []
var events: Array = []


func _ready() -> void:
	remove_test_saves()
	use_fake_clock(WED_2026_10_07, 9, 58)
	CampaignState.new_campaign()
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	await _physics(3)
	DayPhase.phase_changed.connect(func(_a, b): phases.append([b, FMVPlayer.current != null]))

	# Letterboxing on whole internal pixels.
	check(FMVPlayer.letterbox(Vector2i(256, 144)) == Rect2i(0, 30, 320, 180), "16:9 sits in 320x240 with 30px bars")
	check(FMVPlayer.letterbox(Vector2i(320, 240)) == Rect2i(0, 0, 320, 240), "4:3 fills it")
	check(FMVPlayer.letterbox(Vector2i(200, 300)) == Rect2i(80, 0, 160, 240), "portrait gets bars at the sides")

	player.head.rotation.x = -0.3
	player.rotation.y = 1.1
	var before_t := player.global_transform
	var before_head := player.head.rotation
	var mouse_before := Input.mouse_mode
	var fmv := _spawn()
	fmv.play(WIDE, false)
	await _frames(10)
	check(fmv.is_playing() and FMVPlayer.current == fmv, "the clip plays")
	check(fmv.backing.size == Vector2(320, 240) and fmv.backing.color == Color.BLACK, "over a black 320x240 backing")
	check(fmv.video.position == Vector2(0, 30) and fmv.video.size == Vector2(320, 180),
		"letterboxed to the source aspect on whole pixels (%s %s)" % [fmv.video.position, fmv.video.size])
	check(fmv.video.bus == &"FMV" and AudioServer.get_bus_index(&"FMV") >= 0, "its sound goes to the FMV bus")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Ambience")) < -6.0, "the office is ducked, not silenced")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse is let go")

	# Inputs do nothing; the tree is not paused.
	for a in [&"move_forward", &"use", &"examine", &"check_watch", &"crouch"]:
		_action(a, true)
	await _physics(20)
	for a in [&"move_forward", &"use", &"examine", &"check_watch", &"crouch"]:
		_action(a, false)
	var watch: Wristwatch = player.get_node("Head/Eye/Wristwatch")
	check(player.global_transform.origin.is_equal_approx(before_t.origin) and not watch.up and InteractionManager.examined_item == null,
		"walking, using, examining and the watch all do nothing")
	check(not get_tree().paused, "and the scene tree is not paused")

	# The clock crosses 10:00 during the clip; the phase changes then, not later.
	set_local(WED_2026_10_07, 10, 2)
	await _physics(2)
	check(phases.size() == 1 and phases[0] == [DayPhase.Phase.WORKING, true], "the morning ends while the video is playing")
	var hatch := (level.get_node("Hatch") as HandoutInteraction).sounds
	hatch.play(&"knock", &"polite")
	check(FMVPlayer._deferred.size() == 1 and not hatch.knock.playing, "a knock during the clip waits for it to end")

	# A first view: tapping or holding Escape does nothing.
	_action(&"release_mouse", true)
	await _frames(2)
	_action(&"release_mouse", false)
	await _frames(2)
	check(fmv.is_playing(), "a tap of Escape does not stop a first view")
	_action(&"release_mouse", true)
	await _seconds(1.2)
	_action(&"release_mouse", false)
	check(fmv.is_playing() and not fmv.skip_meter.visible, "nor does holding it")

	# Focus out pauses the picture; the clock keeps going.
	fmv.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(fmv.video.paused, "alt-tab pauses the video")
	fmv.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not fmv.video.paused, "and coming back resumes it")

	fmv.fmv_finished.connect(func(i): events.append([&"finished", i]))
	await _until_gone(fmv, 6.0)
	check(events == [[&"finished", &"wide_pattern"]], "it plays to the end (%s)" % [events])
	check(WorldClock.get_now().hour == 10 and WorldClock.get_now().minute == 2, "the clock says 10:02")
	check(DayPhase.phase == DayPhase.Phase.WORKING and LodgementLedger.lodgement_open, "and the office is in the working day: posting is open")
	check(player.global_transform == before_t and player.head.rotation == before_head, "the player is exactly where they were, looking the same way")
	check(not player.movement_locked and not InteractionManager.is_blocked() and Input.mouse_mode == mouse_before, "with input and mouse given back")
	check(FMVPlayer._deferred.is_empty() and hatch.knock.playing, "the knock is heard now")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Ambience")) == 0.0, "the office is back up")

	# Seen before: hold Escape for a second from the first frame.
	check(CampaignState.has_viewed_fmv(&"wide_pattern"), "the clip is recorded as seen")
	CampaignState.commit(&"probe", true)
	CampaignState.clear()
	CampaignState.resume()
	check(CampaignState.has_viewed_fmv(&"wide_pattern"), "and that survives a quit")
	fmv = _spawn()
	fmv.fmv_skipped.connect(func(i): events.append([&"skipped", i]))
	fmv.play(WIDE, false)
	_action(&"release_mouse", true)
	await _seconds(0.5)
	check(fmv.is_playing() and fmv.skip_meter.visible and fmv.skip_meter.size.x > 0, "holding shows a small meter filling")
	await _seconds(0.6)
	_action(&"release_mouse", false)
	check(events.back() == [&"skipped", &"wide_pattern"] and not is_instance_valid(fmv), "a second's hold skips it")
	check(player.global_transform == before_t and not InteractionManager.is_blocked(), "and control is back at once")

	# A first view the caller allows skipping.
	fmv = _spawn()
	fmv.fmv_skipped.connect(func(i): events.append([&"skipped", i]))
	fmv.play(SQUARE, true)
	_action(&"release_mouse", true)
	await _seconds(1.1)
	_action(&"release_mouse", false)
	check(events.back() == [&"skipped", &"test_pattern"], "a clip marked skippable can be skipped first time")

	# A clip that never advances (sound, and no audio device here) cannot
	# hold the day: it is let go.
	fmv = _spawn()
	fmv.fmv_finished.connect(func(i): events.append([&"finished", i]))
	fmv.play("res://tests/fixtures/video/with_sound.ogv", false)
	await _until_gone(fmv, FMVPlayer.STALL_SECONDS + 3.0)
	check(events.back() == [&"finished", &"with_sound"] and not InteractionManager.is_blocked(), "a stalled clip ends itself (%s)" % [events.back()])
	finish()


func _spawn() -> FMVPlayer:
	return FMVPlayer.spawn(level)


func _until_gone(fmv: FMVPlayer, limit: float) -> void:
	var t := 0.0
	while is_instance_valid(fmv) and fmv.visible and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()


func _action(a: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
