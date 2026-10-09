# scripts/systems/waiting_behaviour.gd — JIOH-37: standing at an empty hatch.
#
# The wait is a ladder of beats at fixed fractions of the trade's patience,
# each an absolute unix stamp worked out once at arrival. Evaluation compares
# WorldClock against those stamps, so a trade due to give up at 08:14 has gone
# at 08:14 whether they were on screen, culled, or the game was shut. The
# rendered path (this node, on the Tradesperson) and the headless path
# (simulate_to, used by the scheduler and by absence replay) read the same
# ladder: one implementation, two presentations.
#
# Nothing here slows or pauses because the player is on their way. If they
# left four seconds before the player rounded the corner, they left.
class_name WaitingBehaviour
extends Node

signal beat(trade_id: StringName, beat: StringName)

## [fraction of patience, beat]. Bit i of WaitingProfile.beat_mask gates
## entry i; the departure ignores the mask.
const LADDER := [
	[0.0, &"idle_neutral"],
	[0.15, &"waiting_look_around"],
	[0.3, &"waiting_shift_weight"],
	[0.45, &"knock"],
	[0.6, &"waiting_check_watch"],
	[0.75, &"knock_hard"],
	[0.85, &"phone"],
	[0.95, &"note"],
	[1.0, &"departure"],
]
const ANIM := {
	&"knock": &"knock", &"knock_hard": &"knock", &"phone": &"waiting_phone", &"note": &"write_note",
}

var person: Tradesperson
var slot: ArrivalSlot
var give_up_unix: int = 0
var _ladder: Array[Dictionary] = []
var _next := 0


## The beats this trade will play for an arrival, as absolute stamps.
static func ladder(trade: TradespersonData, arrival_unix: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := trade.waiting if trade.waiting else WaitingProfile.new()
	for i in LADDER.size():
		var b: StringName = LADDER[i][1]
		if b != &"departure":
			if p.beat_mask & (1 << i) == 0:
				continue
			if b == &"phone" and not p.uses_phone:
				continue
			if b == &"note" and not p.leaves_note:
				continue
		out.append({"beat": b, "unix": arrival_unix + roundi(LADDER[i][0] * trade.patience_seconds)})
	return out


## Headless: how far an unattended wait has got by a stamp.
static func simulate_to(trade: TradespersonData, arrival_unix: int, unix: int) -> WaitOutcome:
	var o := WaitOutcome.new()
	for entry in ladder(trade, arrival_unix):
		if entry.unix > unix:
			break
		o.beats.append(entry)
		if entry.beat == &"note":
			o.left_note = true
		if entry.beat == &"departure":
			o.departed = true
			o.departed_unix = entry.unix
	return o


func setup(p: Tradesperson, arrival: ArrivalSlot) -> void:
	person = p
	slot = arrival
	give_up_unix = arrival.patience_expiry_unix
	_ladder = ladder(p.data, arrival.arrival_unix)
	# Beats already behind us (a relaunch, a trade found mid-wait) are not
	# replayed one by one: the trade is simply found at the latest of them.
	var now := WorldClock.now_unix()
	while _next < _ladder.size() and _ladder[_next].unix <= now and _ladder[_next].beat != &"departure":
		_next += 1
	if _next > 0:
		_pose(_ladder[_next - 1].beat)


func _process(_delta: float) -> void:
	if person == null:
		return
	var now := WorldClock.now_unix()
	while _next < _ladder.size() and _ladder[_next].unix <= now:
		var b: StringName = _ladder[_next].beat
		_next += 1
		_pose(b)
		beat.emit(person.data.trade_id, b)


func _pose(b: StringName) -> void:
	if b == &"departure":
		return
	person.play(ANIM.get(b, b))
