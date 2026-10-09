# tests/SourcesProbe.gd — JIOH-26 acceptance criteria: the reception's
# information sources on day 3.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var im


func _ready() -> void:
	im = InteractionManager
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	set_local(WED_2026_10_07, 10, 0)  # day 3
	level = LEVEL.instantiate()
	add_child(level)
	await _frames(2)

	# The planner: trades, sites and days; never job numbers.
	var planner: WallPlanner = level.get_node("Sources/WallPlanner")
	var entries := planner.entries()
	check(entries.has(&"d4_scaffold") and entries[&"d4_scaffold"].day == 4, "the planner has the scaffolders on day 4")
	var all_text := ""
	for e in entries.values():
		for line in e.lines:
			all_text += line[0] + " "
	check(not "J2207" in all_text and not "J2211" in all_text, "and no job number anywhere on it")
	check(InformationBoard.query(&"d4_scaffold", &"job_number").all(func(f): return f.sources == [&"returned_sheets"]),
		"the scaffold job number is only on yesterday's returned sheet")
	check(InformationBoard.query(&"d4_carpentry", &"job_number").all(func(f): return &"terminal_mail" in f.sources),
		"the joinery job number is on the terminal")

	# Key cabinet hooks against the register: plainly different.
	var cabinet: KeyCabinet = level.get_node("Sources/KeyCabinet")
	var register: RegisterBook = level.get_node("Props/KeyRegister")
	check(cabinet.hooks()[14] == ["2.04", "41"], "hook 14 is labelled 2.04 and holds key tag 41")
	var reg_lines: Array = register.grouped()[&"d4_carpentry"].map(func(f): return f.value)
	check("K14" in reg_lines, "the register says K14 for 2.04 (%s)" % [reg_lines])
	check(not cabinet.has_method(&"reconcile") and not register.has_method(&"reconcile"), "nothing reconciles them")

	# The answerphone: a replay is identical; nothing written anywhere.
	var phone: Answerphone = level.get_node("Sources/Answerphone")
	check(phone.tape.size() == 1 and phone.tape[0].message_id == &"msg_kev", "Kev's message is on the tape")
	var started: Array = []
	phone.message_started.connect(func(id): started.append([id, phone.player.stream]))
	im.perform(phone.buttons[&"play"], Interactable.Verb.OPEN)
	check(phone.playing and started.size() == 1, "play plays it")
	await _frames(60)
	var heard := phone.position_s
	im.perform(phone.buttons[&"stop"], Interactable.Verb.OPEN)
	check(not phone.playing and is_equal_approx(phone.position_s, heard), "stop stops where it is")
	im.perform(phone.buttons[&"rewind"], Interactable.Verb.OPEN)
	im.perform(phone.buttons[&"play"], Interactable.Verb.OPEN)
	check(started.size() == 2 and started[1][1] == started[0][1], "rewind and play: the very same recording again")
	var bytes_a: PackedByteArray = (started[0][1] as AudioStreamWAV).data
	Answerphone._murmurs.clear()
	var bytes_b: PackedByteArray = (Answerphone.stream_for(phone.tape[0]) as AudioStreamWAV).data
	check(bytes_a == bytes_b, "even rebuilt from scratch, the placeholder is identical")
	check(phone.find_children("*", "Label3D", true, false).is_empty() and not phone.has_method(&"transcript"),
		"no transcript, subtitle or written reference")
	while phone.playing:
		await _frames(30)
	check(is_equal_approx(phone.position_s, phone.tape_length()), "the tape plays to its end and stops")

	# The terminal: keyboard only, slow to draw.
	var crt: CrtTerminal = level.get_node("Sources/CrtTerminal")
	im.perform(crt.get_node("Interactable"), Interactable.Verb.OPEN)
	check(crt.active and im.player.movement_locked, "using the terminal sits you at it")
	check(crt.screen_text() == "", "the screen takes a moment to draw")
	_press(KEY_DOWN)
	check(crt.selected == 0, "keys pressed while it draws are lost")
	await _frames(int(CrtTerminal.DRAW_SECONDS * 60) + 2)
	var listing := crt.screen_text()
	# Day 3's three, and day 2's two for the slice's morning (JIOH-82).
	check(crt.inbox.size() == 5 and listing.count("\n") == 5, "five mails in the list:\n%s" % listing)
	var moyes := crt.inbox.map(func(m): return m.message_id).find(&"mail_moyes")
	for i in moyes:
		_press(KEY_DOWN)
		await _frames(int(CrtTerminal.DRAW_SECONDS * 60) + 2)
	_press(KEY_ENTER)
	await _frames(int(CrtTerminal.DRAW_SECONDS * 60) + 2)
	var body := crt.screen_text().replace("\n", " ")
	check("J2211" in body and "Room 2.04" in body, "the Moyes mail carries J2211 and the room:\n%s" % crt.screen_text())
	_press(KEY_ESCAPE)
	await _frames(int(CrtTerminal.DRAW_SECONDS * 60) + 2)
	_press(KEY_ESCAPE)
	check(not crt.active and not im.player.movement_locked, "escape twice: back to the office")

	# The drawing rack: both revisions of B-201, nothing to tell them apart but the letter.
	var rack: DrawingRack = level.get_node("Sources/DrawingRack")
	var names := rack.sheets.map(func(s): return String(s.name))
	check(names.size() == 5 and "Drawing_B-201_A" in names and "Drawing_B-201_B" in names, "both revisions hang in the rack %s" % [names])
	var rev_a: DrawingProp = rack.sheets.filter(func(s): return s.drawing.revision == "A" and s.drawing.drawing_no == "B-201")[0]
	var rev_b: DrawingProp = rack.sheets.filter(func(s): return s.drawing.revision == "B" and s.drawing.drawing_no == "B-201")[0]
	var ia: Interactable = rev_a.get_node("Interactable")
	var ib: Interactable = rev_b.get_node("Interactable")
	check(ia.verbs == ib.verbs and ia.tags == ib.tags and ia.display_name == ib.display_name,
		"the superseded sheet behaves and is named exactly like the live one")
	im.perform(ia, Interactable.Verb.PICK_UP)
	check(im.carried_item == ia, "a drawing can be pulled out")
	im.perform(ia, Interactable.Verb.PLACE, Vector3(9.7, 0.76, 3.6))
	check(rev_a.get_parent().name == "Props", "and laid down")
	Answerphone._murmurs.clear()
	finish()


func _press(code: Key) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
