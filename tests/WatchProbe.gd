# tests/WatchProbe.gd — JIOH-67 acceptance criteria.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")


func _ready() -> void:
	use_fake_clock(WED_2026_10_07, 9, 41)
	CampaignState.new_campaign()
	var level: Node3D = LEVEL.instantiate()
	add_child(level)
	var player: PlayerController = level.player
	var watch := player.get_node("Head/Eye/Wristwatch") as Wristwatch
	var im := InteractionManager
	await _physics(2)

	check(watch != null, "the watch is on the player's wrist")
	check(watch.face_text() == "09:41 WED", "the face reads the world clock: hours, minutes, day")
	check(watch.time_label.text == "09:41" and watch.day_label.text == "WED", "and that is what is drawn")
	check(InputMap.has_action(&"check_watch"), "the check_watch action exists")

	# Redraws only on the minute.
	var before := watch.redraws
	await _physics(30)
	check(watch.redraws == before, "no redraw while the minute stands still")
	set_local(WED_2026_10_07, 9, 42)
	await _physics(2)
	check(watch.redraws > before and watch.time_label.text == "09:42", "a new minute redraws the face")

	# Held: up while pressed, down on release; the hands are busy meanwhile.
	_action(true)
	check(watch.up and im.is_blocked(), "pressing raises the watch and blocks interaction")
	await _seconds(Wristwatch.RAISE_SECONDS + 0.1)
	check(watch.rig.transform.origin.is_equal_approx(Wristwatch.UP.origin), "it settles in the lower right of the view")
	_action(false)
	check(not watch.up and not im.is_blocked(), "release lowers it and frees the hands")

	# Toggle mode for accessibility.
	CampaignState.settings["watch_toggle"] = true
	_action(true)
	_action(false)
	check(watch.up, "toggle mode: release leaves it up")
	_action(true)
	check(not watch.up, "and a second press brings it down")
	CampaignState.settings["watch_toggle"] = false

	# Not with a document in hand.
	var docs: Array[DocumentInstance] = [DocumentRegistry.print_document(&"job_sheet")]
	CampaignState.add_document(docs[0])
	var stack := PaperStack.make(docs)
	level.get_node("Props").add_child(stack)
	stack.global_position = Vector3(9.5, 0.76, 3.5)
	im.perform(stack.interactable, Interactable.Verb.PICK_UP)
	_action(true)
	check(not watch.up, "a document in hand: the watch stays down")
	_action(false)
	im.perform(stack.interactable, Interactable.Verb.PLACE, Vector3(9.5, 0.76, 3.5))

	# Not while the terminal or desk has the player.
	player.set_movement_locked(true)
	_action(true)
	check(not watch.up, "locked at the terminal: the watch stays down")
	_action(false)
	player.set_movement_locked(false)
	_action(true)
	check(watch.up, "free again: it comes up")
	_action(false)
	finish()


func _action(pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = &"check_watch"
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
