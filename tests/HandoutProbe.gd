# tests/HandoutProbe.gd — JIOH-30 acceptance criteria, at the hatch in the
# office. Day 4 of a Monday campaign: the carpenter is booked (day 3's
# knowledge) and his pack went into his hole on day 3.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var player: PlayerController
var hatch: HandoutInteraction
var events: Array = []
var finished: Array = []
var day4 := MON_2026_10_05 + 3


func _ready() -> void:
	remove_test_saves()
	_test_read_timing()
	_test_hundred_handouts()

	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	# Keep the counter to one trade: the others have walked for good.
	for id in TradeRoster.shipped().ids():
		if id != &"carpenter":
			CampaignState.get_relationship(id).has_walked = true
	set_local(MON_2026_10_05 + 2, 11, 0)
	var docs: Array[DocumentInstance] = []
	for id in [&"job_sheet", &"permit_to_work", &"rams", &"sign_in_book", &"access_key_docket"]:
		var d := DocumentRegistry.print_document(id)
		d.raised_on_day = 3
		CampaignState.add_document(d)
		docs.append(d)
	LodgementLedger.lodge(&"carpenter", docs)
	set_local(day4, 7, 31)
	await _load_level()

	# The morning: take the pack out of the chippies' hole.
	var hole: PigeonHole = level.get_node("PigeonHoleWall").holes[&"carpenter"]
	var im := InteractionManager
	im.perform(hole, Interactable.Verb.PICK_UP)
	var stack := im.carried_item.body() as PaperStack if im.carried_item else null
	check(stack != null and stack.documents.size() == 5, "at Handout the pack comes out of the hole")
	check(CampaignState.lodgement_log.back().kind == "collected" and docs[0].lodged_in_hole == &"carpenter",
		"logged as collected; the sheets keep the hole they were posted in")
	_stand_at_hatch()

	# Wait for him to arrive, walk up and say good morning.
	var waited := 0
	while hatch.current == null and waited < 60:
		advance(60)
		await _frames(30)
		waited += 1
	await _frames(400)
	check(hatch.current != null and hatch.current.data.trade_id == &"carpenter"
		and hatch.state == HandoutInteraction.State.AWAITING_PACK, "the carpenter is at the hatch, waiting for his pack")
	check(Subtitles.history.size() == 1 and Subtitles.history[0].speaker == &"carpenter", "he said good morning, once")

	# No auto-transfer: standing there holding it does nothing.
	await _frames(60)
	check(im.carried_item == stack.interactable, "holding the pack near the hatch hands nothing over")
	var calls_before := PackValidator.calls
	var hud_before := _visible_controls()
	check(im.perform(hatch.zone, Interactable.Verb.INSERT, im.carried_item), "pushing it into the hatch zone hands it over")
	var man := hatch.current
	check(stack.get_parent() == man.hand_r and is_instance_valid(stack) and im.carried_item == null,
		"the same pack is now in his right hand")
	check(PackValidator.calls == calls_before + 1, "scored once, as it crossed the hatch")
	check(hatch.state == HandoutInteraction.State.READING and man.current_anim == &"read_document", "he reads")
	check(docs.all(func(d): return d.location == CampaignState.Location.HANDED_OVER), "the sheets are handed over")
	var s := hatch.session()
	check(float(s.duration) >= 4.0 and float(s.duration) <= 18.0 and float(s.recheck_at) >= 0.0,
		"a five-page read sits in bounds and has a recheck (%.1fs)" % float(s.duration))
	check(_visible_controls() == hud_before, "no HUD, meter or prompt appears for the read")
	var verdict_saved: Dictionary = s.verdict.duplicate(true)

	# Turn away. Then quit and relaunch a second into the read.
	player.rotation.y += PI
	advance(1)
	await _frames(10)
	check(player.eye.current and get_viewport().get_camera_3d() == player.eye, "the camera stays the player's")
	var rechecks := man.anim_log.count(&"read_document_recheck")
	CampaignState.commit(&"probe", true)
	level.queue_free()
	await _frames(2)
	CampaignState.clear()
	check(CampaignState.resume(), "the save loads")
	await _load_level()
	man = hatch.current
	check(man != null and man.data.trade_id == &"carpenter" and hatch.state == HandoutInteraction.State.READING
		and man.hand_r.get_child_count() == 1, "after a relaunch he is still at the counter, reading the pack")
	hatch.read_finished.connect(func(t, v): finished.append([t, v]))
	var waited_s := 0
	while finished.is_empty() and waited_s < 30:
		advance(1)
		await _frames(6)
		waited_s += 1
	check(finished.size() == 1 and finished[0][1].to_dict() == verdict_saved and PackValidator.calls == calls_before + 1,
		"the read resolves with the saved verdict, not a new score")
	check(rechecks + man.anim_log.count(&"read_document_recheck") == 1, "read_document_recheck happened exactly once")
	await _frames(int(HandoutInteraction.RESOLVE_BEAT * 60) + 10)
	check(hatch.state == HandoutInteraction.State.DEPARTING and hatch.session().is_empty()
		and man.anim_log.back() == &"walk_out", "with nobody resolving yet, he leaves with the pack")
	check(HatchOutcomes.status(&"carpenter", 4) == "served", "his morning is recorded as served")
	remove_test_saves()
	finish()


func _test_read_timing() -> void:
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	var roster := TradeRoster.shipped()
	var gas := roster.get_trade(&"gas_engineer")
	var t := HandoutInteraction.read_timing(gas, 5, 4)
	check(t.seconds <= 18.0 and t.seconds >= 4.0 and t.recheck_at > 0 and t.recheck_at < t.seconds,
		"a slow reader's five pages: capped at 18 seconds with one recheck inside it")
	check(HandoutInteraction.read_timing(gas, 5, 4) == t, "the same day gives the same read")
	check(HandoutInteraction.read_timing(roster.get_trade(&"scaffolder"), 1, 4).seconds == 4.0, "a glance is still four seconds")
	check(HandoutInteraction.read_timing(gas, 3, 4).recheck_at < 0, "three pages or fewer: no recheck")


## A hundred packs of mixed quality: read time must say nothing about the
## verdict beyond what page count and pace already say.
func _test_hundred_handouts() -> void:
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	CampaignState.campaign_seed = 1234
	var roster := TradeRoster.shipped()
	var kinds := [&"job_sheet", &"permit_to_work", &"rams", &"sign_in_book", &"isolation_certificate", &"access_key_docket"]
	var ratio: Array[float] = []
	var raw: Array[float] = []
	var outcome: Array[float] = []
	for i in 100:
		var trade := roster.trades[i % 10]
		var day := 1 + i / 10
		var pages := 1 + (i * 7) % 6
		var pack: Array[DocumentInstance] = []
		for k in pages:
			var d := DocumentRegistry.print_document(kinds[k])
			if (i * 13) % 3 != 0:
				for f in d.template.fields:
					d.set_value(f.key, "X")
			pack.append(d)
		var job := JobRecord.new()
		job.trade = trade.trade_id
		job.start_day = day
		job.end_day = day
		var verdict := PackValidator.score(pack, job, day)
		var secs: float = HandoutInteraction.read_timing(trade, pages, day).seconds
		raw.append(secs)
		ratio.append(secs / clampf(pages * trade.read_pace_seconds_per_page, 4.0, 18.0))
		outcome.append(float(verdict.failures.size()))
	var r_raw := _pearson(raw, outcome)
	var r_res := _pearson(ratio, outcome)
	print("HandoutProbe: duration vs outcome r=%.2f; beyond pages and pace r=%.2f" % [r_raw, r_res])
	check(absf(r_res) < 0.25, "beyond page count and pace, read time carries no usable signal (r=%.2f)" % r_res)


func _pearson(a: Array[float], b: Array[float]) -> float:
	var n := a.size()
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i] / n
		mb += b[i] / n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) ** 2
		sbb += (b[i] - mb) ** 2
	return 0.0 if saa == 0.0 or sbb == 0.0 else sab / sqrt(saa * sbb)


func _load_level() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	hatch = level.get_node("Hatch")
	await _frames(2)


func _stand_at_hatch() -> void:
	player.global_position = Vector3(6.8, 0, 3.625)
	player.rotation.y = PI / 2
	player.head.rotation.x = 0


func _visible_controls() -> int:
	var n := 0
	for c in get_tree().root.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree() and c.get_parent() != Subtitles:
			n += 1
	return n


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
