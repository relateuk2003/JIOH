# scripts/slice/phase_dressing.gd — JIOH-82: what the office looks like in
# each part of the day, applied in the one scene with no scene swap.
#
# DayPhase announces a new phase the moment the clock crosses it; the
# dressing waits if someone is mid-exchange at the hatch, and applies the
# instant the hatch says the exchange has settled. A player mid-sentence is
# never cut off by the building changing around them.
#
# For the slice the dressing is the lighting (JIOH-84): six states from
# resources/render/phase_lighting.tres, crossfaded, so the time can be read
# from the light alone. Fluorescent levels are fractions of each light's
# authored energy; the "Ambient" light is the daylight through the windows.
class_name PhaseDressing
extends Node

signal dressing_applied(phase: int)

const Phase := DayPhase.Phase
const FRONT := [&"ReceptionLight", &"ReceptionLight2", &"LobbyLight"]
const CORRIDOR := [&"CorridorLight", &"CorridorLight2"]
const SUN := &"Ambient"

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
var lighting: PhaseLighting
var _tween: Tween


func _ready() -> void:
	lighting = PhaseLighting.shipped()
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
	_apply(DayPhase.phase, 0.0)


func pending() -> bool:
	return _waiting != -1


func _on_phase_changed(_from: int, to: int) -> void:
	if _hatch and _hatch.is_mid_exchange():
		_waiting = to
		return
	_apply(to, lighting.crossfade_seconds)


func _on_settled() -> void:
	if _waiting != -1:
		var to := _waiting
		_waiting = -1
		_apply(to, lighting.crossfade_seconds)


func _apply(phase: int, seconds: float) -> void:
	applied = phase
	history.append(phase)
	var lights := get_node_or_null(lights_path)
	if _tween:
		_tween.kill()
		_tween = null
	if lights:
		var st := lighting.state(phase)
		if seconds > 0.0:
			_tween = create_tween().set_parallel(true)
		for l in lights.get_children():
			if not (l is Light3D and _authored.has(l.name)):
				continue
			var light := l as Light3D
			var energy: float = _authored[l.name] * _level(l.name, st)
			if l.name == SUN:
				var basis := Basis.from_euler(Vector3(deg_to_rad(st.sun_pitch), deg_to_rad(-150.0), 0.0))
				_put(light, "light_color", st.sun_color, seconds)
				_put(light, "basis", basis, seconds)
				energy = st.sun_energy
			_put(light, "light_energy", energy, seconds)
		# The fill light is lighting, not render configuration: RenderConfig
		# owns the environment's fog and background, this owns its ambient.
		var env := RenderConfig.environment
		if env:
			_put(env, "ambient_light_energy", st.ambient_energy, seconds)
			_put(env, "ambient_light_color", st.ambient_color, seconds)
	dressing_applied.emit(phase)


func _put(target: Object, prop: String, value: Variant, seconds: float) -> void:
	if seconds > 0.0 and _tween:
		_tween.tween_property(target, prop, value, seconds)
	else:
		target.set(prop, value)


func _level(light: StringName, st: Dictionary) -> float:
	if light in FRONT:
		return st.front
	if light in CORRIDOR:
		return st.corridor
	return st.back
