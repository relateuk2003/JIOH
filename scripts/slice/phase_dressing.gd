# scripts/slice/phase_dressing.gd — JIOH-82: what the office looks like in
# each part of the day, applied in the one scene with no scene swap.
#
# DayPhase announces a new phase the moment the clock crosses it; the
# dressing waits if someone is mid-exchange at the hatch, and applies the
# instant the hatch says the exchange has settled. A player mid-sentence is
# never cut off by the building changing around them.
#
# For the slice the dressing is the lights: off overnight, on from pre-open,
# the back rooms off again at wind-down, someone having been round. Every
# light's daytime energy is what the scene authored.
class_name PhaseDressing
extends Node

signal dressing_applied(phase: int)

const Phase := DayPhase.Phase
## Lights that stay on at wind-down: the front of the building.
const FRONT := [&"ReceptionLight", &"ReceptionLight2", &"LobbyLight", &"Ambient"]

@export var lights_path: NodePath = ^"../Lights"
@export var hatch_path: NodePath = ^"../Hatch"

## The phase the room is dressed for, which can trail DayPhase.phase while
## an exchange finishes.
var applied: int = -1
## Every phase the room has been dressed for, in order.
var history: Array[int] = []
var _waiting: int = -1
var _authored: Dictionary = {}  # light name -> energy
var _hatch: HandoutInteraction


func _ready() -> void:
	var lights := get_node_or_null(lights_path)
	if lights:
		for l in lights.get_children():
			if l is Light3D:
				_authored[l.name] = (l as Light3D).light_energy
	_hatch = get_node_or_null(hatch_path) as HandoutInteraction
	if _hatch:
		_hatch.exchange_settled.connect(_on_settled)
	DayPhase.phase_changed.connect(_on_phase_changed)
	# A relaunch is dressed for now at once: there is no exchange to wait on.
	_apply(DayPhase.phase)


func pending() -> bool:
	return _waiting != -1


func _on_phase_changed(_from: int, to: int) -> void:
	if _hatch and _hatch.is_mid_exchange():
		_waiting = to
		return
	_apply(to)


func _on_settled() -> void:
	if _waiting != -1:
		var to := _waiting
		_waiting = -1
		_apply(to)


func _apply(phase: int) -> void:
	applied = phase
	history.append(phase)
	var lights := get_node_or_null(lights_path)
	if lights:
		for l in lights.get_children():
			if l is Light3D and _authored.has(l.name):
				(l as Light3D).light_energy = _authored[l.name] * _level(l.name, phase)
	dressing_applied.emit(phase)


func _level(light: StringName, phase: int) -> float:
	match phase:
		Phase.CLOSED:
			return 0.35 if light == &"Ambient" else 0.0
		Phase.WIND_DOWN:
			return 1.0 if light in FRONT else 0.0
	return 1.0
