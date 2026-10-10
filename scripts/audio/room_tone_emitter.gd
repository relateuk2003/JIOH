# scripts/audio/room_tone_emitter.gd — JIOH-70: one room's quiet.
#
# Sits at the room's Anchor with up to three looping beds (structural,
# electrical, exterior) and a player for incidental one-shots, all on the
# Ambience bus. RoomTone sets the mix; the emitter fades to it in linear
# amplitude, and a layer faded to -INF is stopped outright. One-shots come
# on a randomised timer, sparse, never within the minimum gap of each other
# and never louder than the bed allows. Occlusion is a single low-pass:
# open in the room, closed down next door, more so further away.
class_name RoomToneEmitter
extends Node3D

## Just under Nyquist at the 22050 Hz mix: a cutoff above it makes the
## filter unstable and the bus goes to NaN.
const OPEN_HZ := 10000.0
const NEIGHBOUR_HZ := 2500.0
const ELSEWHERE_HZ := 700.0

var room: StringName
var matrix: RoomToneMatrix
var layers: Dictionary = {}  # layer -> AudioStreamPlayer3D
var incidental: AudioStreamPlayer3D
## Incidental one-shots fired: [emitter seconds, dB, bed dB at the time].
var fired: Array = []
var weekend := false
var rng := RandomNumberGenerator.new()

var _fades: Dictionary = {}  # layer -> {from, to, t, length} in linear amp
var _target_db: Dictionary = {}
var _clock := 0.0
var _next_incidental := 0.0


static func make(room_key: StringName, m: RoomToneMatrix) -> RoomToneEmitter:
	var e := RoomToneEmitter.new()
	e.name = "RoomTone_%s" % room_key
	e.room = room_key
	e.matrix = m
	return e


func _ready() -> void:
	rng.seed = hash([room, CampaignState.campaign_seed])
	for l in RoomToneMatrix.BEDS:
		var kind: StringName = matrix.beds.get("%s/%s" % [room, l], &"")
		if kind == &"":
			continue
		var p := _player(String(l).capitalize())
		p.stream = RoomToneSounds.bed(kind)
		layers[l] = p
		_target_db[l] = -INF
	incidental = _player("Incidental")
	RoomTone.register(self)
	_schedule_incidental()


func _exit_tree() -> void:
	RoomTone.unregister(self)


## Fades every bed to the given mix over `seconds` (0 sets it at once).
func set_mix(mix: Dictionary, seconds: float) -> void:
	for l in layers:
		var to_db: float = mix.get(l, -INF)
		_target_db[l] = to_db
		var to := _amp(to_db)
		var from := _amp(layer_db(l))
		if seconds <= 0.0:
			_fades.erase(l)
			_set_amp(l, to)
		elif not is_equal_approx(from, to):
			_fades[l] = {"from": from, "to": to, "t": 0.0, "length": seconds}
	_target_db[&"incidental"] = mix.get(&"incidental", -INF)


## The level a bed is playing at now; -INF when it is stopped.
func layer_db(l: StringName) -> float:
	var p: AudioStreamPlayer3D = layers.get(l)
	if p == null or not p.playing:
		return -INF
	return p.volume_db


func target_db(l: StringName) -> float:
	return _target_db.get(l, -INF)


## The loudest bed now, which incidentals sit beneath.
func bed_db() -> float:
	var best := -INF
	for l in layers:
		best = maxf(best, layer_db(l))
	return best


func fading() -> bool:
	return not _fades.is_empty()


## 0 in the room, 1 next door, 2 further away.
func set_occlusion(level: int) -> void:
	var hz := [OPEN_HZ, NEIGHBOUR_HZ, ELSEWHERE_HZ][clampi(level, 0, 2)] as float
	for p in layers.values():
		(p as AudioStreamPlayer3D).attenuation_filter_cutoff_hz = hz
	incidental.attenuation_filter_cutoff_hz = hz


func cutoff_hz() -> float:
	return incidental.attenuation_filter_cutoff_hz


func _process(delta: float) -> void:
	advance(delta)


## Moves the emitter's own time on: fades and the incidental schedule.
## Public so a probe can run five minutes of a room in a frame.
func advance(delta: float) -> void:
	_clock += delta
	if _clock >= _next_incidental:
		_fire_incidental()
	for l in _fades.keys():
		var f: Dictionary = _fades[l]
		f.t = minf(f.t + delta, f.length)
		_set_amp(l, lerpf(f.from, f.to, f.t / f.length))
		if f.t >= f.length:
			_fades.erase(l)


func _set_amp(l: StringName, amp: float) -> void:
	var p: AudioStreamPlayer3D = layers[l]
	if amp <= 0.0001:
		# Off means off: no bed at all, not a very quiet one.
		p.stop()
		p.volume_db = -80.0
		return
	p.volume_db = linear_to_db(amp)
	if not p.playing:
		p.play(rng.randf() * RoomToneSounds.LOOP_SECONDS)


func _amp(d: float) -> float:
	return 0.0 if is_inf(d) or d <= -80.0 else db_to_linear(d)


func _schedule_incidental() -> void:
	var mean := matrix.incidental_mean_gap * (2.0 if weekend else 1.0)
	var wait := maxf(matrix.incidental_min_gap, rng.randfn(mean, mean * 0.35))
	_next_incidental = _clock + wait


func _fire_incidental() -> void:
	var pool: Dictionary = matrix.incidentals.get(String(room), {})
	var authored: float = _target_db.get(&"incidental", -INF)
	var bed := bed_db()
	if not pool.is_empty() and not is_inf(authored) and not is_inf(bed):
		var level := minf(authored, bed + matrix.incidental_ceiling_db)
		incidental.stream = RoomToneSounds.one_shot(_pick(pool))
		incidental.volume_db = level
		incidental.play()
		fired.append([_clock, level, bed])
	_schedule_incidental()


func _pick(pool: Dictionary) -> StringName:
	var total := 0.0
	for k in pool:
		total += float(pool[k])
	var r := rng.randf() * total
	for k in pool:
		r -= float(pool[k])
		if r <= 0.0:
			return StringName(k)
	return StringName(pool.keys()[0])


func _player(n: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.bus = &"Ambience"
	p.unit_size = 6.0
	p.max_distance = 45.0
	p.volume_db = -80.0
	p.attenuation_filter_cutoff_hz = OPEN_HZ
	add_child(p)
	return p
