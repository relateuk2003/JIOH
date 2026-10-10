# tests/DeskFillProbe.gd — JIOH-23 acceptance criteria: writing on a form at
# the desk with the pen, through real input events.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var im
var fill: DeskFillController
var commits: Array = []
var signed: Array = []
var ended: Array = []
var refused: Array = []


func _ready() -> void:
	im = InteractionManager
	use_fake_clock(WED_2026_10_07, 10, 0)
	CampaignState.new_campaign()
	level = LEVEL.instantiate()
	add_child(level)
	fill = level.get_node("DeskFill")
	fill.field_committed.connect(func(id, k, v): commits.append([id, k, v]))
	fill.document_signed.connect(func(id): signed.append(id))
	fill.fill_session_ended.connect(func(id): ended.append(id))
	im.interaction_refused.connect(func(_i, r): refused.append(r))
	await _frames(2)

	var top_dir: Vector3 = fill.global_basis * Vector3(0, 0, -1)
	check(top_dir.is_equal_approx(Vector3(-1, 0, 0)), "the sheet lies with its top away from the player (%s)" % top_dir)

	# Lay a two-sheet pack in the slot.
	var docs: Array[DocumentInstance] = []
	for id in [&"permit_to_work", &"job_sheet"]:
		docs.append(DocumentRegistry.print_document(id))
	var pack := PaperStack.make(docs)
	level.get_node("Props").add_child(pack)
	pack.global_position = Vector3(9.5, 0.76, 4.1)
	im.perform(pack.interactable, Interactable.Verb.PICK_UP)
	im.perform(fill.slot, Interactable.Verb.INSERT, im.carried_item)
	var permit := docs[0]
	check(fill.state == DeskFillController.State.DOCUMENT_PLACED and fill.document() == permit,
		"the pack lies in the slot with the permit on top")
	var target := _target(&"job_number")
	check(target.collision_layer == 0, "bare-handed, the boxes cannot be aimed at")

	var pen: Interactable = level.get_node("Props/Pen/Interactable")
	im.perform(pen, Interactable.Verb.PICK_UP)
	check(fill.state == DeskFillController.State.PEN_HELD and target.collision_layer != 0, "pen in hand: the boxes can be")

	# Aim at the job number box from the desk and press use.
	_look_at(target)
	await _physics(3)
	check(im.target == target, "the ray finds the job number box")
	refused.clear()
	im.use()
	check(fill.state == DeskFillController.State.FIELD_ACTIVE and fill.active_field.key == &"job_number",
		"use with the pen opens the box for writing")
	check(im.player.movement_locked, "and the player stays put while writing")

	_type("J4471")
	check(permit.get_value(&"job_number") == "J4471", "typed characters are stored against the field")
	check(fill.sheet.canvas.doc == permit, "and drawn onto that sheet")
	_type("E")
	check(im.carried_item == pen and fill.state == DeskFillController.State.FIELD_ACTIVE,
		"typing E writes an E; it does not trigger use")
	_type("123456")
	check(permit.get_value(&"job_number") == "J4471E12", "past eight characters the box takes no more")
	_key(KEY_BACKSPACE)
	_key(KEY_BACKSPACE)
	_key(KEY_BACKSPACE)
	check(permit.get_value(&"job_number") == "J4471", "backspace rubs out")
	DisplayServer.clipboard_set("PASTED")
	_key(KEY_V, true)
	_key(KEY_Z, true)
	check(permit.get_value(&"job_number") == "J4471", "paste and undo do nothing")

	commits.clear()
	_key(KEY_TAB)
	check(fill.active_field.key == &"location", "tab moves to the next field in printed order")
	check(commits.size() == 1 and commits[0][1] == &"job_number" and commits[0][2] == "J4471",
		"and commits the field it left")
	_key(KEY_TAB)
	check(commits.size() == 2 and commits[1][1] == &"location" and commits[1][2] == "",
		"leaving a box empty commits it empty")
	check(fill.active_field.key == &"valid_from_date", "on to the first date")
	_type("071026")
	check(permit.get_value(&"valid_from_date") == "07/10/26", "a date goes into three two-character boxes")
	check(fill.active_field.key == &"valid_from_time", "filling the third box moves on by itself")
	_type("09:30")
	_key(KEY_TAB)
	_type("0710")
	_key(KEY_TAB)
	check(permit.get_value(&"valid_to_date") == "07/10/", "two boxes and a tab: stored half-written")
	check(WorldClock.epoch_day_from_form_date(permit.get_value(&"valid_to_date")) == -1,
		"which is not a date anyone can read")
	_key(KEY_TAB, false, true)
	check(fill.active_field.key == &"valid_to_date", "shift+tab goes back")
	var fields := permit.template.fields
	fill.activate(fields[0])
	_key(KEY_TAB, false, true)
	check(fill.active_field == fields[fields.size() - 1], "and wraps round from the first box to the last")
	_key(KEY_ESCAPE)
	check(fill.state == DeskFillController.State.PEN_HELD and not im.player.movement_locked, "escape lifts the pen")

	# A tickbox takes a click with the pen.
	var tick := _target(&"prec_ppe")
	im.perform(tick, Interactable.Verb.INSERT, im.carried_item)
	check(permit.get_value(&"prec_ppe") == true, "a click ticks the box")
	im.perform(tick, Interactable.Verb.INSERT, im.carried_item)
	check(permit.get_value(&"prec_ppe") == false, "and another unticks it")

	# A signature takes any stroke: here, a single short scrawl with the mouse.
	im.perform(_target(&"issuer_signature"), Interactable.Verb.INSERT, im.carried_item)
	check(fill.state == DeskFillController.State.SIGNING, "the signature box waits for a stroke")
	_mouse_button(true)
	for i in 4:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(20, -6 + i * 4)
		Input.parse_input_event(m)
	Input.flush_buffered_events()
	_mouse_button(false)
	var sig: Variant = permit.get_value(&"issuer_signature")
	check(sig is Dictionary and (sig.points as PackedVector2Array).size() >= 2, "the stroke is recorded as a polyline")
	check(signed == [permit.instance_id] and permit.signature != null, "document_signed fired; the sheet is signed")
	check(fill.state == DeskFillController.State.PEN_HELD, "and the pen is free again")

	# Nothing in the pass knew right from wrong.
	var v := PackValidator.score([permit] as Array[DocumentInstance], _job(), 1)
	check(v.has(Failure.Code.WRONG_DATE_IN_FIELD), "the half-written date waits for the hatch")

	# Turn to the next sheet by its corner.
	ended.clear()
	im.perform(fill.corner, Interactable.Verb.OPEN)
	check(fill.document() == docs[1] and ended == [permit.instance_id], "the corner turns the page")
	check(fill.sheet.canvas.doc == docs[1], "and the job sheet is now the one in front")

	# Quit and come back: the writing is still on the paper.
	CampaignState.commit(&"probe", true)
	level.queue_free()
	await _frames(2)
	CampaignState.clear()
	check(CampaignState.resume(), "the save loads")
	level = LEVEL.instantiate()
	add_child(level)
	await _frames(2)
	fill = level.get_node("DeskFill")
	var again: DocumentInstance = CampaignState.document_instances[permit.instance_id]
	check(again.get_value(&"job_number") == "J4471" and again.get_value(&"valid_to_date") == "07/10/",
		"after a reload the permit still says what was written")
	check(fill.stack != null and fill.stack.documents.size() == 2, "and the paper is back on the desk")
	finish()


func _job() -> JobRecord:
	var j := JobRecord.new()
	j.job_number = "J4471"
	j.trade = &"electrician"
	j.start_day = 1
	return j


func _target(key: StringName) -> FieldTarget:
	return fill.sheet.get_node("Field_%s" % key)


func _look_at(t: Node3D) -> void:
	var p: PlayerController = im.player
	var aim := (t.get_child(0) as Node3D).global_position
	var at := Vector3(10.25, 0, aim.z)
	p.velocity = Vector3.ZERO
	p.global_position = at
	var to := aim - (at + Vector3(0, p.profile.eye_height, 0))
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _type(text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch.to_upper()) if ch.to_upper() != ch.to_lower() else KEY_NONE
		Input.parse_input_event(e)
		var up := e.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()


func _key(code: Key, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.physical_keycode = code
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func _mouse_button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
