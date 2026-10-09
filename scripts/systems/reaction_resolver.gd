# scripts/systems/reaction_resolver.gd — JIOH-34: what the trade does about
# the pack. Accepted, queried, refused or walked, decided from the verdict
# the hatch saved before the read and from how this trade has been treated.
#
# The reaction is the feedback. No score, grade or tally is ever shown; a
# refusal costs the trade's day and a walk-out costs the trade, and the
# player learns that from the next morning, not from a number.
#
# Every resolution writes back to the relationship and commits at once, so a
# force-quit straight after cannot lose a refusal.
class_name ReactionResolver
extends Node

enum Reaction { ACCEPTED, QUERIED, REFUSED, WALKED }

signal reaction_resolved(trade_id: StringName, reaction: Reaction, fault_id: StringName)
signal query_raised(trade_id: StringName, query: QueryData)
signal query_answered(trade_id: StringName, ok: bool)
signal trade_lost(trade_id: StringName)

const QUERY_MIN := 20.0
const QUERY_MAX := 90.0
## Where a refused pack is put down, on the office side of the counter.
const COUNTER_POINT := Vector3(6.18, 0.979, 3.5)
## Faults the trade will not start on: refuse, never query.
const BLOCKING: Array[Failure.Code] = [
	Failure.Code.UNSIGNED, Failure.Code.EXPIRED, Failure.Code.WRONG_TRADE,
	Failure.Code.UNCLOSED_PREDECESSOR, Failure.Code.WRONG_JOB_NUMBER,
]

var handout: HandoutInteraction
var lines: HatchLines
var _severity: SeverityTable
var _beat_ends := -1.0
var _exit_anim: StringName = &""
var _clock := 0.0


func _ready() -> void:
	handout = get_parent() as HandoutInteraction
	handout.resolver_attached = true
	handout.read_finished.connect(_on_read_finished)
	handout.answer_handler = answer
	lines = load("res://resources/dialogue/hatch_lines.tres")
	_severity = load(PackValidator.SEVERITY_PATH)
	_resume.call_deferred()


## The rules, in order, as a pure decision.
func decide(trade: TradespersonData, rel: RelationshipState, verdict: PackVerdict) -> Dictionary:
	var answerable: Array[Failure] = []
	var blocking: Array[Failure] = []
	for f in verdict.failures:
		if is_answerable(f):
			answerable.append(f)
		elif is_blocking(f):
			blocking.append(f)
	var substantive := not answerable.is_empty() or not blocking.is_empty()
	var recurring := rel.outstanding_query != &"" and verdict.failures.any(
		func(f): return StringName(f.code_name()) == rel.outstanding_query)
	if substantive and (rel.strikes > trade.error_tolerance or recurring):
		return {"reaction": Reaction.WALKED, "fault": _first_fault(blocking, answerable)}
	if not blocking.is_empty():
		return {"reaction": Reaction.REFUSED, "fault": blocking[0]}
	if not answerable.is_empty():
		return {"reaction": Reaction.QUERIED, "fault": answerable[0]}
	return {"reaction": Reaction.ACCEPTED, "fault": verdict.failures[0] if not verdict.failures.is_empty() else null}


## A sheet the player could hand over now, or a box they could fill.
func is_answerable(f: Failure) -> bool:
	return (f.code == Failure.Code.MISSING_DOCUMENT and not f.blocking) or f.code == Failure.Code.MISSING_FIELD


func is_blocking(f: Failure) -> bool:
	if f.code == Failure.Code.MISSING_DOCUMENT:
		return f.blocking
	return f.code in BLOCKING or _severity.severity_of(f) >= PackVerdict.Severity.REJECTED


static func query_window(trade: TradespersonData) -> float:
	return clampf(trade.patience_seconds * 0.5, QUERY_MIN, QUERY_MAX)


# --- Live -------------------------------------------------------------------

func _on_read_finished(trade_id: StringName, verdict: PackVerdict) -> void:
	var t := handout.current
	var rel := CampaignState.get_relationship(trade_id)
	var d := decide(t.data, rel, verdict)
	var fault: Failure = d.fault
	match d.reaction:
		Reaction.QUERIED:
			var q := QueryData.from_failure(fault)
			var s := handout.session()
			s["state"] = "awaiting_answer"
			s["query"] = q.to_dict()
			s["answer_by"] = WorldClock.now_unix() + int(query_window(t.data))
			CampaignState.commit(&"query", true)
			t.play(&"read_document_recheck")
			_say(t, lines.line_for(q.voice_line_id, _variant(t)))
			t.play(&"idle_impatient")
			query_raised.emit(trade_id, q)
		_:
			_resolve(d.reaction, fault)


## A sheet handed across while a query stands. The hatch calls this.
func answer(stack: PaperStack) -> void:
	var s := handout.session()
	var q := QueryData.from_dict(s.get("query", {}))
	var ok := stack.documents.any(func(doc): return q.answered_by(doc))
	var t := handout.current
	stack.reparent(t.hand_r, false)
	stack.transform = Transform3D(Basis(), Vector3(0, 0.004, 0))
	var held := t.hand_r.get_child(0) as PaperStack
	if held and held != stack:
		held.put_on_top(stack)
	for doc in (held if held else stack).documents:
		doc.location = CampaignState.Location.HANDED_OVER
		CampaignState.add_document(doc)
	query_answered.emit(t.data.trade_id, ok)
	if ok:
		_resolve(Reaction.ACCEPTED, null, true)
	else:
		_resolve(Reaction.REFUSED, _fault_from(q))


func _tick() -> void:
	var s := handout.session()
	if s.get("state") == "awaiting_answer" and WorldClock.now_unix() >= int(s.answer_by):
		var q := QueryData.from_dict(s.query)
		var rel := CampaignState.get_relationship(StringName(s.trade_id))
		rel.outstanding_query = q.fault_id
		query_answered.emit(StringName(s.trade_id), false)
		_resolve(Reaction.REFUSED, _fault_from(q))


func _process(delta: float) -> void:
	_clock += delta
	if _beat_ends >= 0.0 and _clock >= _beat_ends:
		_beat_ends = -1.0
		handout.finish_resolution(_exit_anim)
	elif _beat_ends < 0.0 and handout.session().get("state") == "awaiting_answer":
		_tick()


func _resolve(reaction: Reaction, fault: Failure, query_resolved := false) -> void:
	var t := handout.current
	var id := t.data.trade_id
	var rel := CampaignState.get_relationship(id)
	match reaction:
		Reaction.ACCEPTED:
			if not query_resolved:
				rel.strikes = maxi(rel.strikes - 1, 0)
				rel.goodwill += 1.0
			rel.days_since_last_success = 0
			rel.outstanding_query = &""
		Reaction.REFUSED:
			rel.strikes += 1
			rel.days_since_last_success += 1
		Reaction.WALKED:
			rel.strikes += 1
			rel.has_walked = true
	var fault_id := StringName(fault.code_name()) if fault else &""
	HatchOutcomes.record_reaction(id, WorldClock.get_campaign_day(), Reaction.keys()[reaction].to_lower(), fault_id, query_resolved)
	var s := handout.session()
	s["state"] = "resolved"
	s["reaction"] = int(reaction)
	CampaignState.commit(&"reaction", true)
	_perform(reaction, fault)
	reaction_resolved.emit(id, reaction, fault_id)
	if reaction == Reaction.WALKED:
		trade_lost.emit(id)


## Body language and the line. A walk-out is a beat of stillness and no line
## at all: the silence is the line.
func _perform(reaction: Reaction, fault: Failure) -> void:
	var t := handout.current
	var secs := 1.0
	match reaction:
		Reaction.ACCEPTED:
			t.play(&"sign_document")
			secs = _say(t, t.data.voice_set.line_for(&"accepted", _variant(t)))
			_exit_anim = &"walk_out"
		Reaction.REFUSED:
			secs = _say(t, lines.line_for(fault.spoken_line_id, _variant(t)) if fault else "")
			secs += _say_later(t, t.data.voice_set.line_for(&"refused", _variant(t)), secs)
			_return_pack(t)
			t.play(&"shrug")
			_exit_anim = &"walk_out"
		Reaction.WALKED:
			_return_pack(t)
			t.play(&"idle_neutral")
			secs = 2.0
			_exit_anim = &"walk_out_annoyed"
	_beat_ends = _clock + secs


func _return_pack(t: Tradesperson) -> void:
	if t.hand_r.get_child_count() == 0:
		return
	var stack := t.hand_r.get_child(0) as PaperStack
	var props := handout.get_parent().get_node_or_null("Props")
	stack.reparent(props if props else handout.get_parent(), false)
	stack.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), COUNTER_POINT)
	stack.interactable.set_targetable(true)
	for doc in stack.documents:
		doc.location = CampaignState.Location.DESK
	CampaignState.commit(&"pack_returned")


## After a relaunch: a standing query picks up its window where it was; a
## resolution that was already written plays its exit and nothing more.
func _resume() -> void:
	var s := handout.session()
	if s.is_empty() or handout.current == null:
		return
	match s.get("state"):
		"resolving":
			_on_read_finished(StringName(s.trade_id), PackVerdict.from_dict(s.verdict))
		"awaiting_answer":
			handout.state = HandoutInteraction.State.RESOLVING
			handout.current.play(&"idle_impatient")
		"resolved":
			var r: Reaction = int(s.reaction) as Reaction
			if r == Reaction.REFUSED or r == Reaction.WALKED:
				_return_pack(handout.current)
			_exit_anim = &"walk_out_annoyed" if r == Reaction.WALKED else &"walk_out"
			_beat_ends = _clock


func _say(t: Tradesperson, text: String) -> float:
	if text == "":
		return 0.0
	var secs := Subtitles.seconds_for(text, t.data.voice_set.words_per_minute)
	Subtitles.say(t.data.trade_id, text, secs)
	return secs


## A second line after a real pause; subtitles carry the timing.
func _say_later(t: Tradesperson, text: String, after: float) -> float:
	if text == "":
		return 0.0
	var secs := Subtitles.seconds_for(text, t.data.voice_set.words_per_minute)
	var id := t.data.trade_id
	get_tree().create_timer(after + 0.6).timeout.connect(func(): Subtitles.say(id, text, secs))
	return secs + 0.6


func _variant(t: Tradesperson) -> int:
	return ArrivalScheduler.day_rng(t.data.trade_id, WorldClock.get_campaign_day()).randi()


func _fault_from(q: QueryData) -> Failure:
	var f := Failure.new()
	f.code = Failure.Code.keys().find(String(q.fault_id)) as Failure.Code
	f.spoken_line_id = q.voice_line_id
	if not q.accepted_document_types.is_empty():
		f.doc_id = q.accepted_document_types[0]
	f.field_key = q.field_key
	return f


func _first_fault(a: Array[Failure], b: Array[Failure]) -> Failure:
	return a[0] if not a.is_empty() else (b[0] if not b.is_empty() else null)
