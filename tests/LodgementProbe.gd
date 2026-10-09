# tests/LodgementProbe.gd — JIOH-32 acceptance criteria, at the pigeon hole
# wall in the office.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var player: PlayerController
var wall: PigeonHoleWall
var lodged: Array = []
var retrieved: Array = []
var refused: Array = []
var closed := 0


func _ready() -> void:
	use_fake_clock(WED_2026_10_07, 9, 0)
	CampaignState.new_campaign()
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	wall = level.get_node("PigeonHoleWall")
	LodgementLedger.pack_lodged.connect(func(t, ids): lodged.append([t, ids]))
	LodgementLedger.pack_retrieved.connect(func(t, ids): retrieved.append([t, ids]))
	LodgementLedger.lodgement_closed.connect(func(): closed += 1)
	InteractionManager.interaction_refused.connect(func(i, r): refused.append(r))
	var im := InteractionManager
	await _physics(2)

	check(wall.holes.size() == 10, "one hole per trade")
	var sparks: PigeonHole = wall.holes[&"electrician"]
	var chippies: PigeonHole = wall.holes[&"carpenter"]

	# At Handout the flaps are up for collection, but nothing can be posted.
	check(wall.flaps_open() and not LodgementLedger.lodgement_open, "09:00: flaps up for collection only")
	var early := _stack_on_desk([&"job_sheet"])
	im.perform(early.interactable, Interactable.Verb.PICK_UP)
	refused.clear()
	im.perform(sparks, Interactable.Verb.INSERT, im.carried_item)
	check(refused == ["pigeon_holes_collect_only"] and im.carried_item == early.interactable,
		"posting before 10:00 is refused and the stack stays in hand")
	im.perform(early.interactable, Interactable.Verb.PLACE, Vector3(9.5, 0.76, 3.5))

	set_local(WED_2026_10_07, 10, 0)
	await _physics(2)
	check(wall.flaps_open() and LodgementLedger.lodgement_open, "10:00: posting opens")

	# Post a two-sheet pack into the sparks' hole by looking at it and pressing use.
	var pack := _stack_on_desk([&"job_sheet", &"permit_to_work"])
	var ids: Array[StringName] = [pack.documents[0].instance_id, pack.documents[1].instance_id]
	im.perform(pack.interactable, Interactable.Verb.PICK_UP)
	_stand_and_look(sparks)
	await _physics(3)
	check(im.target == sparks, "the sparks' hole is targeted from in front of the wall")
	im.use()
	check(im.carried_item == null and sparks.stack == pack, "use posts the held stack into the hole")
	check(pack.documents.all(func(d): return d.lodged_in_hole == &"electrician" \
		and d.lodged_at_unix == WorldClock.now_unix() and d.location == CampaignState.Location.LODGED),
		"every sheet records the hole and the lodgement time")
	check(lodged.size() == 1 and lodged[0][0] == &"electrician" and lodged[0][1] == ids,
		"pack_lodged carries the trade and the ids, and nothing else")
	check(pack.visible and pack.get_parent().get_parent().name == "Hole_electrician" \
		and pack.global_position.distance_to(sparks.global_position) < 0.2,
		"the pack sits visibly in that hole")
	check(CampaignState.today_record().lodgements_made == 1, "the day's record counts the lodgement")

	# The wrong hole: accepted, no question, no correction.
	var wrong := _stack_on_desk([&"isolation_certificate"])
	im.perform(wrong.interactable, Interactable.Verb.PICK_UP)
	refused.clear()
	_stand_and_look(chippies)
	await _physics(3)
	im.use()
	check(refused.is_empty() and chippies.stack == wrong and wrong.documents[0].lodged_in_hole == &"carpenter",
		"an electrician's certificate goes into the chippies' hole without a word")
	check(LodgementLedger.contents_of(&"carpenter") == wrong.documents,
		"and that is what the carpenter will collect")

	# Second thoughts at 14:00: the whole stack comes out, in order.
	set_local(WED_2026_10_07, 14, 0)
	_stand_and_look(sparks)
	await _physics(3)
	im.use()
	check(im.carried_item == pack.interactable and sparks.stack == null, "reaching in takes the stack back out")
	check(pack.documents.map(func(d): return d.instance_id) == ids, "in its original order")
	check(pack.documents.all(func(d): return d.lodged_in_hole == &"" and d.location == CampaignState.Location.DESK),
		"the sheets are no longer lodged")
	var log := CampaignState.lodgement_log
	check(log.size() == 3 and log[0].kind == "lodged" and log[2].kind == "retrieved" \
		and Array(log[2].ids) == ids.map(func(i): return String(i)),
		"the retrieval is appended; the original lodgement entry is still there")
	check(retrieved.size() == 1 and retrieved[0][0] == &"electrician", "pack_retrieved fired")
	# Post it again, then put a single sheet on top of it: one stack, in order.
	im.use()
	var extra := _stack_on_desk([&"rams"])
	im.perform(extra.interactable, Interactable.Verb.PICK_UP)
	_stand_and_look(sparks)
	await _physics(3)
	im.use()
	check(sparks.stack == pack and pack.documents.size() == 3 \
		and (not is_instance_valid(extra) or extra.is_queued_for_deletion()),
		"a second post joins the stack already in the hole")
	check(LodgementLedger.contents_of(&"electrician").size() == 3, "the ledger agrees: three sheets")

	# A pack left on the desk at the cutoff.
	var forgotten := _stack_on_desk([&"job_sheet"])
	var forgotten_doc := forgotten.documents[0]
	set_local(WED_2026_10_07, 15, 30)
	await _physics(2)
	check(closed == 1 and not wall.flaps_open(), "15:30: the flaps come down")
	refused.clear()
	im.perform(forgotten.interactable, Interactable.Verb.PICK_UP)
	im.perform(sparks, Interactable.Verb.INSERT, im.carried_item)
	check(refused == ["pigeon_holes_closed"] and forgotten_doc.lodged_in_hole == &"",
		"after the cutoff nothing can be posted")
	refused.clear()
	im.perform(forgotten.interactable, Interactable.Verb.PLACE, Vector3(9.5, 0.76, 3.5))
	im.perform(chippies, Interactable.Verb.PICK_UP)
	check(refused == ["pigeon_holes_closed"] and chippies.stack == wrong, "nor taken back out")
	check(LodgementLedger.contents_of(&"electrician").size() == 3, "lodged packs stay lodged")

	# Wind-down does not reopen the holes; the next working morning does.
	set_local(WED_2026_10_07, 16, 30)
	await _physics(2)
	check(not wall.flaps_open() and not LodgementLedger.lodgement_open, "16:30 wind-down: still closed")
	set_local(THU_2026_10_08, 9, 0)
	check(is_instance_valid(forgotten) and forgotten_doc.raised_on_day == 1 \
		and forgotten_doc.location != CampaignState.Location.LODGED,
		"the forgotten pack is still on the desk next morning, a day older, not lodged")
	check(not LodgementLedger.contents_of(&"electrician").has(forgotten_doc), "and it is not in any hole")

	# Quit and come back: the holes are rebuilt from the save.
	CampaignState.commit(&"probe", true)
	var before := LodgementLedger.contents_of(&"electrician").map(func(d): return d.instance_id)
	level.queue_free()
	await _physics(2)
	CampaignState.clear()
	check(CampaignState.resume(), "the save loads")
	level = LEVEL.instantiate()
	add_child(level)
	wall = level.get_node("PigeonHoleWall")
	await _physics(2)
	var restored: PigeonHole = wall.holes[&"electrician"]
	check(restored.stack != null and restored.stack.documents.map(func(d): return d.instance_id) == before,
		"after a reload the sparks' hole holds the same sheets in the same order")
	check((wall.holes[&"carpenter"] as PigeonHole).stack != null, "and the chippies' hole its wrong one")
	check(wall.flaps_open() and not LodgementLedger.lodgement_open, "and at 09:00 the flaps are up for collection, posting shut")
	finish()


func _stack_on_desk(doc_ids: Array) -> PaperStack:
	var docs: Array[DocumentInstance] = []
	for id in doc_ids:
		var d := DocumentRegistry.print_document(id)
		CampaignState.add_document(d)
		docs.append(d)
	var s := PaperStack.make(docs)
	level.get_node("Props").add_child(s)
	s.global_position = Vector3(9.5, 0.76, 3.5)
	return s


func _stand_and_look(hole: PigeonHole) -> void:
	var mouth := (hole.get_child(0) as Node3D).global_position
	var at := Vector3(mouth.x, 0, mouth.z + 0.9)
	player.velocity = Vector3.ZERO
	player.global_position = at
	var to := mouth - (at + Vector3(0, player.profile.eye_height, 0))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
