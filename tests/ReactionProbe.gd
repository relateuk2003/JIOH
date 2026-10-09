# tests/ReactionProbe.gd — JIOH-34 acceptance criteria. Each case is a fresh
# day-4 morning with only the carpenter booked, handed a pack built clean for
# his job (J2211, Room 2.04, key K14) and then broken in one way.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const R := ReactionResolver.Reaction

var level: Node3D
var player: PlayerController
var hatch: HandoutInteraction
var resolver: ReactionResolver
var job: JobRecord
var resolved: Array = []
var queries: Array = []
var lost: Array = []


func _ready() -> void:
	remove_test_saves()
	await _case_clean()
	await _case_query_answered()
	await _case_query_timeout()
	await _case_blocking()
	await _case_walk()
	_case_decide_rules()
	remove_test_saves()
	finish()


func _case_clean() -> void:
	await _morning(func(r): r.strikes = 2)
	await _hand_over(_pack([&"job_sheet", &"permit_to_work", &"rams", &"access_key_docket"]))
	await _until_resolved()
	var rel := CampaignState.get_relationship(&"carpenter")
	check(resolved == [[&"carpenter", R.ACCEPTED, &""]] and rel.strikes == 1 and rel.goodwill == 1.0,
		"a clean pack is accepted: a strike forgiven, goodwill up")
	check(hatch.current.anim_log.has(&"sign_document"), "he signs")
	await _until_gone()
	check(_stack_left_on_counter() == null, "and takes the pack with him")
	await _close()


func _case_query_answered() -> void:
	await _morning()
	var docket := _pack([&"access_key_docket"])
	await _hand_over(_pack([&"job_sheet", &"permit_to_work", &"rams"]))
	await _until_read()
	check(queries.size() == 1 and queries[0][1].fault_id == &"MISSING_DOCUMENT"
		and &"access_key_docket" in queries[0][1].accepted_document_types, "the missing key docket is queried")
	check(Subtitles.history.back().text in (resolver.lines.lines[&"hatch_missing_document"] as PackedStringArray),
		"in his own words, naming the fault")
	check(resolved.is_empty() and hatch.can_take_pack(), "and he waits for an answer")
	_hold(docket)
	check(InteractionManager.perform(hatch.zone, Interactable.Verb.INSERT, InteractionManager.carried_item), "the docket goes across")
	var rel := CampaignState.get_relationship(&"carpenter")
	check(resolved.size() == 1 and resolved[0][1] == R.ACCEPTED and rel.strikes == 0,
		"the query is promoted to accepted, and no strike is recorded")
	check(HatchOutcomes.reaction(&"carpenter", 4).query_resolved, "recorded as a query resolved on the spot")
	check(hatch.current.hand_r.get_child(0).documents.size() == 4, "the docket joins the pack in his hand")
	await _close()


func _case_query_timeout() -> void:
	await _morning()
	await _hand_over(_pack([&"job_sheet", &"permit_to_work", &"rams"]))
	await _until_read()
	var window := ReactionResolver.query_window(TradeRoster.shipped().get_trade(&"carpenter"))
	check(window == 90.0, "the carpenter gives a query half his patience, capped at ninety seconds")
	for i in int(window) + 2:
		advance(1)
		if i % 10 == 0:
			await _frames(1)
	await _frames(2)
	var rel := CampaignState.get_relationship(&"carpenter")
	check(resolved.size() == 1 and resolved[0][1] == R.REFUSED and rel.strikes == 1,
		"no answer in the window: the query becomes a refusal and a strike")
	check(rel.outstanding_query == &"MISSING_DOCUMENT", "the unanswered query is remembered")
	# Force-quit straight after: the write-back is already on disk.
	CampaignState.clear()
	CampaignState.resume()
	check(CampaignState.get_relationship(&"carpenter").strikes == 1
		and HatchOutcomes.reaction(&"carpenter", 4).reaction == "refused", "a force-quit straight after keeps the strike")
	await _close()


func _case_blocking() -> void:
	await _morning()
	var hud_before := _visible_controls()
	await _hand_over(_pack([&"permit_to_work", &"rams", &"access_key_docket"]))
	await _until_resolved()
	check(queries.is_empty() and resolved.size() == 1 and resolved[0][1] == R.REFUSED,
		"no job sheet: refused outright, no query offered")
	var stack := _stack_left_on_counter()
	check(stack != null and stack.documents.size() == 3 and stack.interactable.collision_layer != 0,
		"the pack is put back on the counter, still wrong, and can be picked up")
	check(stack != null and stack.documents.all(func(d): return d.location == CampaignState.Location.DESK),
		"its sheets are the player's again")
	check(hatch.current.anim_log.has(&"shrug"), "he shrugs")
	await _until_gone()
	check(_visible_controls() == hud_before and Subtitles.history.all(func(h): return not RegEx.create_from_string("\\d").search(h.text)),
		"no score, grade or number is shown, only what he says")
	check(_stack_left_on_counter() != null, "the pack is still there after he has gone")
	await _close()


func _case_walk() -> void:
	await _morning(func(r): r.strikes = 4)
	CampaignState.get_day(5).scheduled_trades = [&"carpenter"]
	await _hand_over(_pack([&"permit_to_work", &"rams", &"access_key_docket"]))
	var lines_before := Subtitles.history.size()
	await _until_resolved()
	var rel := CampaignState.get_relationship(&"carpenter")
	check(resolved.size() == 1 and resolved[0][1] == R.WALKED and rel.has_walked and lost == [&"carpenter"],
		"four strikes against a tolerance of three, and another bad pack: he walks")
	check(Subtitles.history.size() == lines_before, "without a word")
	await _until_gone()
	check(hatch.current == null or hatch.current.data.trade_id != &"carpenter", "he is gone")
	var sched: ArrivalScheduler = level.get_node("ArrivalScheduler")
	CampaignState.clear()
	CampaignState.resume()
	check(CampaignState.get_relationship(&"carpenter").has_walked, "the walk-out survives a restart")
	var later := true
	for d in range(5, 15):
		later = later and sched.build_day_schedule(d).all(func(s): return s.trade_id != &"carpenter")
	check(later, "and he is in no later day's schedule")
	await _close()


func _case_decide_rules() -> void:
	var r := ReactionResolver.new()
	r._severity = load(PackValidator.SEVERITY_PATH)
	var trade := TradeRoster.shipped().get_trade(&"gas_engineer")
	var rel := RelationshipState.new()
	var v := PackVerdict.new()
	check(r.decide(trade, rel, v).reaction == R.ACCEPTED, "nothing wrong: accepted")
	var minor := Failure.make(Failure.Code.UNSTAMPED)
	v.failures = [minor]
	check(r.decide(trade, rel, v).reaction == R.ACCEPTED, "a missing stamp is grumbled at, not queried")
	v.failures = [Failure.make(Failure.Code.MISSING_FIELD)]
	check(r.decide(trade, rel, v).reaction == R.QUERIED, "a blank box is queried")
	v.failures = [Failure.make(Failure.Code.UNSIGNED), Failure.make(Failure.Code.MISSING_FIELD)]
	check(r.decide(trade, rel, v).reaction == R.REFUSED, "unsigned beats a blank box: refused")
	rel.strikes = 1
	v.failures = [Failure.make(Failure.Code.MISSING_FIELD)]
	check(r.decide(trade, rel, v).reaction == R.WALKED, "the gas engineer tolerates nothing: one strike and a fault, he walks")
	rel.strikes = 0
	rel.outstanding_query = &"MISSING_FIELD"
	check(r.decide(trade, rel, v).reaction == R.WALKED, "the same fault as yesterday's unanswered query: he walks")
	r.free()


# --- Fixtures -----------------------------------------------------------------

## A fresh campaign on day 4, 07:31, only the carpenter booked and willing.
func _morning(adjust := Callable()) -> void:
	resolved.clear()
	queries.clear()
	lost.clear()
	Subtitles.history.clear()
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	for id in TradeRoster.shipped().ids():
		if id != &"carpenter":
			CampaignState.get_relationship(id).has_walked = true
	if adjust.is_valid():
		adjust.call(CampaignState.get_relationship(&"carpenter"))
	job = InformationBoard.live_jobs_on(4).filter(func(j): return j.trade == &"carpenter")[0]
	set_local(MON_2026_10_05 + 3, 7, 31)
	level = LEVEL.instantiate()
	add_child(level)
	player = level.player
	hatch = level.get_node("Hatch")
	resolver = hatch.get_node("ReactionResolver")
	resolver.reaction_resolved.connect(func(t, re, f): resolved.append([t, re, f]))
	resolver.query_raised.connect(func(t, q): queries.append([t, q]))
	resolver.trade_lost.connect(func(t): lost.append(t))
	player.global_position = Vector3(6.8, 0, 3.625)
	player.rotation.y = PI / 2
	await _frames(2)


func _hand_over(stack: PaperStack) -> void:
	_hold(stack)
	var waited := 0
	while hatch.current == null and waited < 90:
		advance(60)
		await _frames(2)
		waited += 1
	while hatch.state != HandoutInteraction.State.AWAITING_PACK and waited < 2000:
		await _frames(1)
		waited += 1
	InteractionManager.perform(hatch.zone, Interactable.Verb.INSERT, InteractionManager.carried_item)


func _hold(stack: PaperStack) -> void:
	InteractionManager.perform(stack.interactable, Interactable.Verb.PICK_UP)


func _until_read() -> void:
	var n := 0
	while hatch.state == HandoutInteraction.State.READING and n < 30:
		advance(1)
		await _frames(2)
		n += 1


func _until_resolved() -> void:
	await _until_read()
	var n := 0
	while resolved.is_empty() and n < 60:
		await _frames(2)
		n += 1


func _until_gone() -> void:
	var n := 0
	while hatch.state != HandoutInteraction.State.DEPARTING and n < 1500:
		await _frames(1)
		n += 1


func _close() -> void:
	level.queue_free()
	await _frames(2)


func _pack(ids: Array) -> PaperStack:
	var docs: Array[DocumentInstance] = []
	var e := CampaignState.get_day(4).epoch_day
	for id in ids:
		var doc := DocumentRegistry.print_document(id)
		doc.raised_on_day = 3
		for f in doc.template.fields:
			match f.type:
				DocumentField.FieldType.DATE: doc.set_value(f.key, WorldClock.form_date(e))
				DocumentField.FieldType.TIME: doc.set_value(f.key, "08:00")
				DocumentField.FieldType.NUMBER: doc.set_value(f.key, "1")
				DocumentField.FieldType.TICKBOX: doc.set_value(f.key, true)
				DocumentField.FieldType.SIGNATURE: doc.set_value(f.key, {"by": "player"})
				_: doc.set_value(f.key, "X")
		var known := {&"job_number": job.job_number, &"trade": "Carpenter", &"location": job.location, &"site": job.site,
			&"key_number": job.key_number, &"permit_number": job.permit_number}
		for k in known:
			if doc.template.get_field(k):
				doc.set_value(k, known[k])
		if doc.template.requires_stamp:
			doc.apply_stamp(&"received", WorldClock.date_string(e))
		if id == &"rams":
			doc.set_value(&"assessment_date", WorldClock.form_date(e - 2))
		CampaignState.add_document(doc)
		docs.append(doc)
	var s := PaperStack.make(docs)
	level.get_node("Props").add_child(s)
	s.global_position = Vector3(6.6, 0.0, 3.0)
	return s


func _stack_left_on_counter() -> PaperStack:
	for c in level.get_node("Props").get_children():
		if c is PaperStack and c.global_position.distance_to(ReactionResolver.COUNTER_POINT) < 0.05:
			return c
	return null


func _visible_controls() -> int:
	var n := 0
	for c in get_tree().root.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree() and c.get_parent() != Subtitles:
			n += 1
	return n


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
