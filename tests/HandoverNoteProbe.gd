# tests/HandoverNoteProbe.gd — JIOH-57 acceptance criteria: Janice's note is
# the whole of the onboarding, and it is just paper.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const NOTE := preload("res://resources/text/handover_note.tres")

var level: Node3D
var im


func _ready() -> void:
	im = InteractionManager
	remove_test_saves()
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	_load_level()
	await _physics(2)

	# Present from the first moment, within reach of where you start.
	var spot: HandoverNote = level.get_node("HandoverNote")
	var note := spot.stack
	check(note != null and note.documents.size() == NOTE.page_count and NOTE.page_count >= 2,
		"the note is on the desk, %d sides of it" % NOTE.page_count)
	check(level.player.global_position.distance_to(note.global_position) < 1.2, "within reach of where you start")
	check(note.documents.map(func(d): return String(d.instance_id)) == ["handover_note_1", "handover_note_2", "handover_note_3", "handover_note_4"].slice(0, NOTE.page_count),
		"its sheets are in order")
	check(not _has_overlay(level) and Subtitles.history.is_empty(), "no overlay, popup, tooltip or caption on arrival")
	check(not Engine.has_singleton("Tutorial") and get_node_or_null("/root/Tutorial") == null, "no tutorial system exists")

	# What it says, and what it does not.
	var words := NOTE.text.to_lower()
	check(words.contains("hatch") and words.contains("collect") and words.contains("half seven"),
		"it says the trades collect at the hatch each morning")
	check(words.contains("tomorrow's packs"), "that the day is for the next morning's paperwork")
	check(words.contains("15:30") and words.contains("close"), "that lodgement closes at 15:30")
	for banned in ["press", "click", "button", "mouse", "keyboard", "controls", "[e]", "left-click"]:
		check(not words.contains(banned), "and nothing about inputs (\"%s\")" % banned)

	# Ignoring it: a whole day passes and nothing nags.
	set_local(MON_2026_10_05, 12, 0)
	await _physics(2)
	set_local(MON_2026_10_05, 16, 30)
	await _physics(2)
	set_local(20732, 7, 45)  # Tuesday
	await _physics(2)
	check(not HandoverNote.taken() and spot.stack == note and is_instance_valid(note), "unread, it is still on the desk next morning")
	check(Subtitles.history.is_empty() and not _has_overlay(level), "nothing prompted or reminded")
	check(DayPhase.phase == DayPhase.Phase.HANDOUT and CampaignState.story_flags.get(HandoverNote.READ_FLAG) == null,
		"and the morning goes on as normal")

	# Reading it: the same paper and the same clipboard as everything else.
	var view: HeldDocumentView = level.player.get_node("Head/Eye/HeldDocumentView")
	im.perform(note.interactable, Interactable.Verb.PICK_UP)
	check(view.state == HeldDocumentView.State.RAISED and view.document() == note.documents[0], "picked up, it goes on the clipboard")
	check(HandoverNote.taken() and CampaignState.story_flags.get(HandoverNote.READ_FLAG) == WorldClock.now_unix(),
		"note_read_first_time is recorded")
	check(not view.begin_writing(), "there is nowhere on it to write")
	for i in NOTE.page_count - 1:
		view.next_page()
		await _seconds(0.3)
	check(view.page == NOTE.page_count - 1, "every side can be turned to")

	# Put down, reloaded, and found in the drawer on day 12.
	im.perform(note.interactable, Interactable.Verb.PLACE, Vector3(9.4, 0.76, 2.95))
	CampaignState.commit(&"probe", true)
	level.queue_free()
	await _physics(2)
	CampaignState.clear()
	check(CampaignState.resume(), "the save loads")
	set_local(20742, 10, 0)  # Friday the 16th
	check(WorldClock.get_campaign_day() == 12, "it is day 12")
	_load_level()
	await _physics(2)
	spot = level.get_node("HandoverNote")
	check(spot.stack == null, "the desk no longer has the note on it")
	var drawer: DeskDrawer = level.get_node("DeskDrawer")
	check(drawer.stacks().size() == 1 and not drawer.stacks()[0].interactable.collision_layer, "shut, the drawer's contents cannot be reached")
	im.perform(drawer.handle, Interactable.Verb.OPEN)
	var kept := drawer.stacks()[0]
	check(drawer.is_open() and kept.interactable.collision_layer != 0, "opened, the note is there to take")
	check(kept.documents.map(func(d): return String(d.instance_id)) == note_ids(), "all of it, in order")
	check(kept.documents.all(func(d): return d.template.handwriting == NOTE), "and it is the same writing")
	view = level.player.get_node("Head/Eye/HeldDocumentView")
	im.perform(kept.interactable, Interactable.Verb.PICK_UP)
	check(view.document() == kept.documents[NOTE.page_count - 1], "it opens where it was left")
	im.perform(drawer.receiver, Interactable.Verb.INSERT, im.carried_item)
	check(drawer.stacks().size() == 1 and im.carried_item == null, "and goes back in the drawer")

	# The handwriting is the text, baked; the accessible lines are the same.
	var all_lines: Array = []
	for i in NOTE.page_count:
		var baked := NOTE.texture.get_image().get_region(Rect2i(HandwrittenText.PAGE.x * i, 0, HandwrittenText.PAGE.x, HandwrittenText.PAGE.y))
		baked.convert(Image.FORMAT_RGBA8)
		check(baked.get_data() == NOTE.render(i).get_data(), "page %d texture matches the text (rebake if not)" % (i + 1))
		all_lines.append_array(NOTE.page_lines(i))
	var joined := " ".join(all_lines.filter(func(l): return l != "")).split(" ", false)
	var source := NOTE.text.replace("\n", " ").split(" ", false)
	check(joined == source, "the accessible presentation carries every word of the note")
	var fits := all_lines.all(func(l): return JiohFonts.width_of(l, JiohFonts.Face.BODY) <= HandwrittenText.PAGE.x - HandwrittenText.LEFT)
	check(fits and NOTE.layout().size() == NOTE.page_count, "set in the body face at 1x, every line fits the page")
	finish()


func note_ids() -> Array:
	var out := []
	for i in NOTE.page_count:
		out.append("handover_note_%d" % (i + 1))
	return out


func _load_level() -> void:
	level = LEVEL.instantiate()
	add_child(level)


func _has_overlay(n: Node) -> bool:
	for c in n.get_children():
		if c is SubViewport:
			continue  # faces and pages drawn onto props, not the screen
		if c is CanvasLayer or c is Control:
			return true
		if _has_overlay(c):
			return true
	return false


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
