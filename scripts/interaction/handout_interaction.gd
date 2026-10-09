# scripts/interaction/handout_interaction.gd — JIOH-30: the thirty seconds the
# game turns on. Someone at the hatch takes the pack you made yesterday and
# reads it, and nothing tells you how it is going.
#
# One trade at the counter at a time; later arrivals queue behind. The pack
# is scored the moment it crosses the hatch, before the read begins, and the
# verdict is saved with the read, so a reload mid-read delivers the same
# answer without scoring again. Read time is page count times the trade's
# pace with a seeded jitter: it is never derived from the verdict, so a long
# read means nothing, which is what makes it unbearable.
#
# No HUD, meter or prompt. The camera is never taken; the only nudge is one
# soft turn toward the trade when they first speak.
class_name HandoutInteraction
extends Node3D

enum State { APPROACHING, WAITING_FOR_PLAYER, GREETING, AWAITING_PACK, READING, RESOLVING, DEPARTING }

signal pack_offered(trade_id: StringName)
signal pack_taken(trade_id: StringName, pack: PaperStack)
signal read_started(trade_id: StringName, duration: float)
signal read_finished(trade_id: StringName, pack_score: PackVerdict)
signal state_changed(trade_id: StringName, state: State)
## The exchange at the counter has reached a point where the day may move on
## (JIOH-82): phase dressing that waited for it applies now.
signal exchange_settled

const READ_MIN := 4.0
const READ_MAX := 18.0
const READ_JITTER := 0.2
## How close, on the office side, counts as being at the hatch.
const GREET_DISTANCE := 2.6
## With no reaction resolver attached, how long after the read they leave.
const RESOLVE_BEAT := 1.5
const DOOR := Vector3(4.0, 0.0, 7.4)
const QUEUE_STEP := Vector3(-0.15, 0.0, 0.75)

@export var handover_point: Marker3D
@export var zone: HatchHandoverZone

var scheduler: ArrivalScheduler
var roster: TradeRoster
var current: Tradesperson = null
var state: State = State.APPROACHING
var queue: Array[Tradesperson] = []
## Set by the reaction resolver (JIOH-34) when it takes over RESOLVING.
var resolver_attached := false
## Takes a sheet handed across while a query stands (JIOH-34).
var answer_handler: Callable
var sounds: HatchSounds
var _leaving: Array[Tradesperson] = []
var _notes: Dictionary = {}  # note id -> HatchNote
var _greet_ends := 0.0
var _resolve_ends := 0.0
var _clock := 0.0
var _nudged := false


func _ready() -> void:
	roster = TradeRoster.shipped()
	if handover_point == null:
		handover_point = get_node_or_null("HandoverPoint")
	if zone == null:
		zone = get_node_or_null("HatchHandoverZone")
	zone.handout = self
	sounds = HatchSounds.new()
	sounds.name = "Sounds"
	add_child(sounds)
	scheduler = get_parent().get_node_or_null("ArrivalScheduler") as ArrivalScheduler
	if scheduler:
		scheduler.arrival_due.connect(_on_arrival)
		scheduler.gave_up.connect(_on_gave_up)
	WorldClock.minute_elapsed.connect(_tick_read)
	_restore()
	_refresh_notes.call_deferred()


# --- Arrivals and the queue -------------------------------------------------

func _on_arrival(slot: ArrivalSlot) -> void:
	if _find(slot.trade_id):
		return
	var trade := roster.get_trade(slot.trade_id)
	if trade == null:
		return
	var t := Tradesperson.make(trade, slot)
	add_child(t)
	t.place_at(DOOR, Vector3.FORWARD)
	var wait := WaitingBehaviour.new()
	wait.name = "WaitingBehaviour"
	t.add_child(wait)
	wait.setup(t, slot)
	wait.beat.connect(_on_beat)
	queue.append(t)
	_shuffle_queue()


## A beat of someone's wait. Knocks and the phone are heard wherever the
## player is; the departure hands straight back to the scheduler so they go
## on their stamp, to the second.
func _on_beat(trade_id: StringName, b: StringName) -> void:
	var trade := roster.get_trade(trade_id)
	match b:
		&"knock", &"knock_hard", &"phone":
			if b != &"phone" or trade.waiting.uses_phone:
				sounds.play(b, trade.waiting.knock_style)
		&"waiting_look_around", &"waiting_check_watch":
			var p := InteractionManager.player
			if trade.waiting.mutters and p and is_instance_valid(p) and p.global_position.distance_to(global_position) < 8.0:
				var line := trade.voice_set.line_for(&"waiting", ArrivalScheduler.day_rng(trade_id, WorldClock.get_campaign_day()).randi())
				Subtitles.say(trade_id, line, Subtitles.seconds_for(line, trade.voice_set.words_per_minute))
		&"departure":
			if scheduler:
				scheduler.check_now()


## Notes left on the counter by trades who gave up, until picked up.
func _refresh_notes() -> void:
	var props := get_parent().get_node_or_null("Props")
	var i := 0
	for data in HatchOutcomes.notes_on_counter():
		var id := String(data.id)
		if not _notes.has(id):
			var n := HatchNote.make(data)
			(props if props else get_parent()).add_child(n)
			n.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(6.2, 0.978, 3.05 + 0.13 * i))
			_notes[id] = n
		i += 1


func _on_gave_up(slot: ArrivalSlot) -> void:
	_refresh_notes()
	var t := _find(slot.trade_id)
	if t == null or (t == current and state >= State.READING):
		return
	queue.erase(t)
	if t == current:
		current = null
	_depart(t, &"walk_out_annoyed")
	_shuffle_queue()


func _shuffle_queue() -> void:
	if current == null and not queue.is_empty():
		current = queue.pop_front()
		_set_state(State.APPROACHING)
		current.walk_to(handover_point.global_position)
		if not current.arrived.is_connected(_on_current_arrived):
			current.arrived.connect(_on_current_arrived.bind(current), CONNECT_ONE_SHOT)
	for i in queue.size():
		queue[i].walk_to(handover_point.global_position + QUEUE_STEP * (i + 1) + Vector3(-0.4, 0, 0))


func _on_current_arrived(t: Tradesperson) -> void:
	if t != current or state != State.APPROACHING:
		return
	t.place_at(handover_point.global_position, handover_point.global_basis.z)
	t.play(&"idle_neutral")
	_set_state(State.WAITING_FOR_PLAYER)


# --- At the counter ---------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	match state:
		State.WAITING_FOR_PLAYER:
			if current and _player_at_hatch():
				_greet()
		State.GREETING:
			if _clock >= _greet_ends:
				_set_state(State.AWAITING_PACK)
				pack_offered.emit(current.data.trade_id)
		State.READING:
			_tick_read()
		State.RESOLVING:
			if not resolver_attached and _clock >= _resolve_ends:
				finish_resolution(&"walk_out")


func _player_at_hatch() -> bool:
	var p := InteractionManager.player
	if p == null or not is_instance_valid(p):
		return false
	var pos := p.global_position
	return pos.x > global_position.x and pos.distance_to(global_position) <= GREET_DISTANCE


func _greet() -> void:
	_set_state(State.GREETING)
	var line := current.data.voice_set.line_for(&"greeting", _pick(&"greeting"))
	var secs := Subtitles.seconds_for(line, current.data.voice_set.words_per_minute)
	Subtitles.say(current.data.trade_id, line, secs)
	_greet_ends = _clock + secs
	var p := InteractionManager.player
	if not _nudged and p and is_instance_valid(p):
		_nudged = true
		p.nudge_toward(current.head.global_position)


func can_take_pack() -> bool:
	if current == null:
		return false
	if state == State.RESOLVING:
		return awaiting_answer() and answer_handler.is_valid()
	return state in [State.WAITING_FOR_PLAYER, State.GREETING, State.AWAITING_PACK]


func awaiting_answer() -> bool:
	return session().get("state") == "awaiting_answer"


## The pack crosses the hatch. Called from the zone when the player pushes a
## held stack into it; scripted sequences and tests call it the same way.
func take_pack(stack: PaperStack) -> void:
	if state == State.RESOLVING:
		answer_handler.call(stack)
		return
	var trade := current.data
	var day := WorldClock.get_campaign_day()
	stack.reparent(current.hand_r, false)
	stack.transform = Transform3D.IDENTITY
	stack.visible = true
	stack.interactable.set_targetable(false)
	var docs: Array[DocumentInstance] = stack.documents.duplicate()
	for doc in docs:
		doc.location = CampaignState.Location.HANDED_OVER
		CampaignState.add_document(doc)
	if scheduler:
		scheduler.mark_served(trade.trade_id)
	var wait := current.get_node_or_null("WaitingBehaviour")
	if wait:
		wait.queue_free()
	current.play(&"receive")
	pack_taken.emit(trade.trade_id, stack)
	# Timing first, from page count and pace alone; then the verdict, which
	# timing never sees.
	var timing := read_timing(trade, docs.size(), day)
	var verdict := PackValidator.score(docs, _job_for(trade.trade_id, day), day)
	var now := float(WorldClock.now_unix())
	_save_session({
		"trade_id": String(trade.trade_id),
		"ids": docs.map(func(d): return String(d.instance_id)),
		"read_start": now,
		"duration": timing.seconds,
		"recheck_at": timing.recheck_at,
		"rechecked": false,
		"verdict": verdict.to_dict(),
		"state": "reading",
	})
	_set_state(State.READING)
	current.play(&"read_document")
	read_started.emit(trade.trade_id, timing.seconds)


## Read time for a pack: pages times pace, jittered by up to a fifth from the
## same per-trade, per-day seed as the arrival. Takes no verdict, by design.
static func read_timing(trade: TradespersonData, pages: int, campaign_day: int) -> Dictionary:
	var rng := ArrivalScheduler.day_rng(trade.trade_id, campaign_day)
	rng.randfn()  # the arrival's draw
	var jitter := rng.randf_range(-READ_JITTER, READ_JITTER)
	var seconds := clampf(pages * trade.read_pace_seconds_per_page * (1.0 + jitter), READ_MIN, READ_MAX)
	var recheck := -1.0
	if pages > 3:
		recheck = seconds * rng.randf_range(0.35, 0.8)
	return {"seconds": seconds, "recheck_at": recheck}


func _tick_read() -> void:
	if state != State.READING or current == null:
		return
	var s := session()
	var elapsed := float(WorldClock.now_unix()) - float(s.read_start)
	if float(s.recheck_at) >= 0.0 and not s.rechecked and elapsed >= float(s.recheck_at):
		s.rechecked = true
		current.play(&"read_document_recheck")
		CampaignState.commit(&"hatch_read")
	if elapsed >= float(s.duration):
		s.state = "resolving"
		CampaignState.commit(&"hatch_read", true)
		_set_state(State.RESOLVING)
		_resolve_ends = _clock + RESOLVE_BEAT
		read_finished.emit(current.data.trade_id, PackVerdict.from_dict(s.verdict))


## The reaction resolver (JIOH-34) calls this once it has played its part.
## The trade leaves with whatever they are holding.
func finish_resolution(exit_anim: StringName) -> void:
	var t := current
	_clear_session()
	_depart(t, exit_anim)
	current = null
	_shuffle_queue()


func session() -> Dictionary:
	return CampaignState.today_record().get("hatch_session", {})


func _save_session(s: Dictionary) -> void:
	var rec := CampaignState.today_record()
	if not rec.is_empty():
		rec["hatch_session"] = s
		CampaignState.commit(&"hatch_read", true)


func _clear_session() -> void:
	var rec := CampaignState.today_record()
	if rec.has("hatch_session"):
		rec.erase("hatch_session")
		CampaignState.commit(&"hatch_read", true)


## A reload mid-read: the trade is back at the counter holding the pack and
## the read carries on from the saved stamp with the saved verdict.
func _restore() -> void:
	var s := session()
	if not s.is_empty():
		var trade := roster.get_trade(StringName(s.trade_id))
		var docs: Array[DocumentInstance] = []
		for id in s.ids:
			var doc: DocumentInstance = CampaignState.document_instances.get(StringName(id))
			if doc:
				docs.append(doc)
		current = Tradesperson.make(trade)
		add_child(current)
		current.place_at(handover_point.global_position, handover_point.global_basis.z)
		var stack := PaperStack.make(docs)
		current.hand_r.add_child(stack)
		stack.interactable.set_targetable(false)
		_nudged = true
		if s.state == "reading":
			_set_state(State.READING)
			current.play(&"read_document")
		else:
			_set_state(State.RESOLVING)
			_resolve_ends = _clock
	if scheduler:
		for slot in scheduler.present():
			_on_arrival(slot)


func _depart(t: Tradesperson, anim: StringName) -> void:
	if t == null:
		return
	if state != State.DEPARTING and t == current:
		_set_state(State.DEPARTING)
	t.play(anim)
	_leaving.append(t)
	t.walk_to(DOOR)
	t.arrived.connect(_gone.bind(t), CONNECT_ONE_SHOT)


func _gone(t: Tradesperson) -> void:
	_leaving.erase(t)
	t.queue_free()


func _set_state(s: State) -> void:
	var was := is_mid_exchange()
	state = s
	state_changed.emit(current.data.trade_id if current else &"", s)
	if was and not is_mid_exchange():
		exchange_settled.emit()


## Someone is talking, reading or reacting at the counter: a phase change
## must not cut across it (JIOH-82). Waiting for the pack is not an exchange
## in this sense; nobody is mid-sentence.
func is_mid_exchange() -> bool:
	return current != null and is_instance_valid(current) \
		and state in [State.GREETING, State.READING, State.RESOLVING]


func _find(trade_id: StringName) -> Tradesperson:
	if current and current.data.trade_id == trade_id:
		return current
	for t in queue:
		if t.data.trade_id == trade_id:
			return t
	return null


func _pick(situation: StringName) -> int:
	var rng := ArrivalScheduler.day_rng(current.data.trade_id, WorldClock.get_campaign_day())
	return rng.randi() + situation.length()


func _job_for(trade_id: StringName, day: int) -> JobRecord:
	for job in InformationBoard.live_jobs_on(day):
		if job.trade == trade_id:
			return job
	# A regular with nothing booked (the cleaner) still needs a standing job.
	var j := JobRecord.new()
	j.job_id = StringName("standing_%s" % trade_id)
	j.trade = trade_id
	j.start_day = day
	j.end_day = day
	return j

