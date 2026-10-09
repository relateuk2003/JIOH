# tests/ClipboardProbe.gd — JIOH-71 acceptance criteria: paper on the
# clipboard, through real input events.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const DESK := Vector3(9.5, 0.76, 3.5)

var level: Node3D
var player: PlayerController
var view: HeldDocumentView
var im
var turned: Array = []
var written: Array = []
var refused: Array = []


func _ready() -> void:
	im = InteractionManager
	use_fake_clock(WED_2026_10_07, 11, 0)
	CampaignState.new_campaign()
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	view = player.get_node("Head/Eye/HeldDocumentView")
	view.page_turned.connect(func(i): turned.append(i))
	view.field_written.connect(func(f, v): written.append([f.key, v]))
	im.interaction_refused.connect(func(_i, r): refused.append(r))
	await _physics(2)
	check(not view.clipboard.visible, "no paper, no clipboard")

	# Aim at a pack on the desk and use it.
	var pack := _stack_on_desk([&"job_sheet", &"permit_to_work", &"rams"])
	var docs := pack.documents.duplicate()
	_stand_and_look(pack)
	await _physics(3)
	_aim(pack.global_position + Vector3(0, 0.01, 0))
	await _physics(2)
	check(im.target == pack.interactable, "the pack on the desk is targeted")
	im.use()
	check(view.state == HeldDocumentView.State.RAISED and view.clipboard.visible and not pack.visible,
		"use clips it to the board and lifts it")
	await _seconds(HeldDocumentView.MOVE_SECONDS + 0.1)
	check(view.clipboard.transform.is_equal_approx(HeldDocumentView.UP), "the board is up in front of the eyes")
	check(view.clipboard.leaf.doc == docs[0] and view.page == 0, "page one is on top")
	var to_page := player.eye.global_transform.affine_inverse() * view.clipboard.leaf.global_position
	check(absf(to_page.x) < 0.05 and to_page.z < -0.3 and to_page.z > -0.45,
		"the page is square in the middle of the view at reading distance (%s)" % to_page)
	check(is_equal_approx(player.speed_scale, HeldDocumentView.READING_SPEED), "reading: a slow walk, not a stop")
	check(not player.movement_locked, "and the player can still move")

	# Next page: a quarter-second flip with a sound.
	_action(&"next_page", true)
	_action(&"next_page", false)
	check(view.state == HeldDocumentView.State.TURNING and view.clipboard.turns == 1, "next page starts a turn, with its sound")
	check(view.clipboard.anim.current_animation == "turn_next"
		and is_equal_approx(view.clipboard.anim.current_animation_length, 0.25), "the flip takes a quarter of a second")
	check(view.clipboard.under.doc == docs[1], "the next page shows beneath the turning leaf")
	await _seconds(0.3)
	check(view.state == HeldDocumentView.State.RAISED and view.clipboard.leaf.doc == docs[1] and turned == [1],
		"after the turn, page two is on top")
	_action(&"previous_page", true)
	_action(&"previous_page", false)
	await _seconds(0.3)
	check(view.clipboard.leaf.doc == docs[0] and turned == [1, 0], "previous page goes back")
	_action(&"previous_page", true)
	_action(&"previous_page", false)
	check(turned == [1, 0] and view.clipboard.turns == 2, "nothing before page one")

	# Write into the first box and confirm.
	var sheet: DocumentInstance = docs[0]
	_action(&"write_field", true)
	_action(&"write_field", false)
	var f: DocumentField = view.writer.active_field
	check(view.state == HeldDocumentView.State.WRITING and f != null, "write brings the biro to a box")
	check(player.movement_locked and im.is_blocked(), "writing stands you still and busies the hands")
	var before := int(CampaignState.today_record().get("fields_written", 0))
	_type("J2211")
	_key(KEY_ENTER)
	check(view.state == HeldDocumentView.State.RAISED and not player.movement_locked, "enter puts the biro back")
	check(sheet.get_value(f.key) == "J2211", "the value is on the document (%s)" % [sheet.get_value(f.key)])
	check(written.size() == 1 and written[0] == [f.key, "J2211"], "field_written carried it")
	check(CampaignState.document_instances.get(sheet.instance_id) == sheet
		and int(CampaignState.today_record().get("fields_written", 0)) == before + 1,
		"and it is recorded against today in the campaign")

	# The watch will not come up over a held document.
	var watch: Wristwatch = player.get_node("Head/Eye/Wristwatch")
	_action(&"check_watch", true)
	check(not watch.up and view.state == HeldDocumentView.State.RAISED and view.page == 0
		and view.clipboard.leaf.doc == sheet, "the watch stays down; the document stays up, unchanged")
	_action(&"check_watch", false)

	# Examine drops the board to the side to see the way.
	_action(&"examine", true)
	_action(&"examine", false)
	check(view.state == HeldDocumentView.State.ASIDE and im.examined_item == null and is_equal_approx(player.speed_scale, 1.0),
		"examine lowers the board to your side at full pace")
	_action(&"examine", true)
	_action(&"examine", false)
	check(view.state == HeldDocumentView.State.RAISED, "and raises it again")

	# Left open on page three, put down, picked up later.
	view.next_page()
	await _seconds(0.3)
	view.next_page()
	await _seconds(0.3)
	check(view.page == 2, "on page three")
	refused.clear()
	im.perform(pack.interactable, Interactable.Verb.PLACE, DESK)
	check(view.state == HeldDocumentView.State.EMPTY and pack.visible and refused.is_empty(),
		"put down with empty boxes left: no objection, no warning")
	check(not player.movement_locked and is_equal_approx(player.speed_scale, 1.0), "hands free, full pace")
	await _seconds(0.3)
	check(not view.clipboard.visible, "the clipboard goes away with the paper")
	set_local(WED_2026_10_07, 14, 0)
	im.perform(pack.interactable, Interactable.Verb.PICK_UP)
	check(view.page == 2 and view.clipboard.leaf.doc == docs[2], "picked up at 14:00 it opens on page three")
	check(sheet.get_value(f.key) == "J2211", "with what was written still there")

	# Through a quit: the page is kept on the pack's first sheet.
	im.perform(pack.interactable, Interactable.Verb.PLACE, DESK)
	CampaignState.commit(&"probe", true)
	CampaignState.clear()
	CampaignState.resume()
	var back: DocumentInstance = CampaignState.document_instances.get(sheet.instance_id)
	check(back != null and back.open_page == 2 and back.get_value(f.key) == "J2211", "the open page and the writing survive a reload")

	# JIOH-11: a bigger page.
	CampaignState.settings["large_page"] = true
	var single := _stack_on_desk([&"job_sheet"])
	im.perform(single.interactable, Interactable.Verb.PICK_UP)
	await _seconds(HeldDocumentView.MOVE_SECONDS + 0.1)
	check(view.clipboard.transform.is_equal_approx(HeldDocumentView.UP_LARGE), "large-page setting holds it closer")
	CampaignState.settings["large_page"] = false
	finish()


func _stack_on_desk(doc_ids: Array) -> PaperStack:
	var docs: Array[DocumentInstance] = []
	for id in doc_ids:
		var d := DocumentRegistry.print_document(id)
		CampaignState.add_document(d)
		docs.append(d)
	var s := PaperStack.make(docs)
	level.get_node("Props").add_child(s)
	s.global_position = DESK
	return s


func _stand_and_look(s: PaperStack) -> void:
	var at := s.global_position + Vector3(0, 0, 0.6)
	at.y = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	var to := s.global_position - (at + Vector3(0, player.profile.eye_height, 0))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _aim(at: Vector3) -> void:
	var to := at - player.eye.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _action(a: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _type(text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch)
		Input.parse_input_event(e)
		var up := e.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.physical_keycode = code
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
