# scripts/slice/phase_lighting.gd — JIOH-84: the six lighting states, one per
# day phase. The light is how the player tells the time, so each state is
# distinct by colour and angle as well as level. Tune in
# resources/render/phase_lighting.tres; PhaseDressing crossfades between them.
class_name PhaseLighting
extends Resource

const PATH := "res://resources/render/phase_lighting.tres"

## Per phase (DayPhase.Phase order): fluorescent levels for the front of the
## building, the corridor and the back rooms (fractions of each light's
## authored energy), the daylight through the windows, and the room's
## ambient fill (environment ambient light).
@export var states: Array[Dictionary] = [
	# CLOSED: nobody in, a little night through the blinds.
	{"front": 0.0, "corridor": 0.0, "back": 0.0,
		"sun_energy": 0.12, "sun_color": Color(0.35, 0.42, 0.62), "sun_pitch": -60.0,
		"ambient_energy": 0.3, "ambient_color": Color(0.26, 0.3, 0.42)},
	# PRE_OPEN: a dark room; only the corridor is lit, coming under the door.
	{"front": 0.0, "corridor": 0.7, "back": 0.0,
		"sun_energy": 0.16, "sun_color": Color(0.55, 0.6, 0.78), "sun_pitch": -12.0,
		"ambient_energy": 0.55, "ambient_color": Color(0.32, 0.33, 0.38)},
	# HANDOUT: tubes on, a cool early morning outside.
	{"front": 1.0, "corridor": 1.0, "back": 1.0,
		"sun_energy": 0.3, "sun_color": Color(0.82, 0.88, 1.0), "sun_pitch": -25.0,
		"ambient_energy": 0.95, "ambient_color": Color(0.34, 0.35, 0.37)},
	# WORKING: flat midday, the office at its most office.
	{"front": 1.0, "corridor": 1.0, "back": 1.0,
		"sun_energy": 0.36, "sun_color": Color(1.0, 1.0, 0.95), "sun_pitch": -58.0,
		"ambient_energy": 1.0, "ambient_color": Color(0.35, 0.35, 0.33)},
	# CUTOFF: the afternoon turning warm.
	{"front": 1.0, "corridor": 1.0, "back": 1.0,
		"sun_energy": 0.34, "sun_color": Color(1.0, 0.9, 0.76), "sun_pitch": -32.0,
		"ambient_energy": 1.0, "ambient_color": Color(0.38, 0.34, 0.29)},
	# WIND_DOWN: back rooms off, low sun through the blinds.
	{"front": 0.7, "corridor": 0.5, "back": 0.0,
		"sun_energy": 0.65, "sun_color": Color(1.0, 0.62, 0.36), "sun_pitch": -8.0,
		"ambient_energy": 0.85, "ambient_color": Color(0.42, 0.32, 0.25)},
]
## Crossfade between states, seconds of play.
@export var crossfade_seconds: float = 4.0


static func shipped() -> PhaseLighting:
	var l := load(PATH) as PhaseLighting
	return l if l else PhaseLighting.new()


func state(phase: int) -> Dictionary:
	return states[clampi(phase, 0, states.size() - 1)]
