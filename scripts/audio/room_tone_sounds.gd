# scripts/audio/room_tone_sounds.gd — JIOH-70: placeholder room tone,
# synthesised until the recorded set exists (JIOH-8). Beds are seamless
# four-second loops; one-shots are short and dry. Authored clean, like any
# source: the era bus does the ageing.
class_name RoomToneSounds
extends RefCounted

const RATE := 22050
const LOOP_SECONDS := 4.0
const FADE := 0.25

static var _cache: Dictionary = {}


static func bed(kind: StringName) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _loop(_bed_samples(kind))
	return _cache[kind]


static func one_shot(kind: StringName) -> AudioStreamWAV:
	var key := StringName("shot_" + kind)
	if not _cache.has(key):
		_cache[key] = _wav(_shot_samples(kind), false)
	return _cache[key]


static func _bed_samples(kind: StringName) -> PackedFloat32Array:
	var n := int(RATE * (LOOP_SECONDS + FADE))
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := HatchSounds.randf_noise(i * 31 + kind.hash() % 997)
		brown = brown * 0.995 + white * 0.03
		lp = lp * 0.9 + white * 0.1
		var v := 0.0
		match kind:
			&"boiler":
				# The heating: a low burner roar with a slow breath to it.
				v = (sin(TAU * 45.0 * t) * 0.45 + sin(TAU * 90.0 * t) * 0.2 + brown * 3.0) \
					* (0.8 + 0.2 * sin(TAU * 0.25 * t))
			&"lights":
				# Strip lights: mains buzz and its harmonics.
				v = sin(TAU * 100.0 * t) * 0.35 + sin(TAU * 200.0 * t) * 0.2 \
					+ sin(TAU * 300.0 * t) * 0.12 + sin(TAU * 400.0 * t) * 0.06 + lp * 0.08
			&"fridge":
				# A compressor that has been running all night.
				v = (sin(TAU * 50.0 * t) * 0.4 + sin(TAU * 150.0 * t) * 0.15 + lp * 0.12) \
					* (0.85 + 0.15 * sin(TAU * 0.5 * t))
			&"traffic":
				# Traffic beyond the windows, swelling and passing.
				v = brown * 4.0 * (0.6 + 0.4 * sin(TAU * 0.25 * t))
			_:
				v = brown * 2.0
		s[i] = v
	# Every bed peaks at the same level, so the matrix alone sets loudness.
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	for i in n:
		s[i] *= 0.5 / maxf(peak, 0.001)
	return s


static func _shot_samples(kind: StringName) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var length := {&"tick": 0.12, &"creak": 0.6, &"thump": 0.5}.get(kind, 0.3) as float
	s.resize(int(RATE * length))
	var prev := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var white := HatchSounds.randf_noise(i * 13 + 7)
		var v := 0.0
		match kind:
			&"tick":
				# A pipe expanding as the heating comes up.
				v = sin(TAU * 1800.0 * t) * exp(-t * 90.0)
			&"creak":
				# The building settling: a slow, narrow groan.
				prev = prev * 0.97 + white * 0.03
				v = sin(TAU * (180.0 + 120.0 * t) * t) * 0.5 * sin(PI * t / length) + prev * 2.0
			&"thump":
				# A door somewhere else in the building.
				v = sin(TAU * 60.0 * t) * exp(-t * 14.0) + white * 0.2 * exp(-t * 40.0)
		s[i] = clampf(v, -1.0, 1.0) * 0.8
	return s


## The tail crossfaded into the head, so the loop has no seam.
static func _loop(raw: PackedFloat32Array) -> AudioStreamWAV:
	var loop_n := int(RATE * LOOP_SECONDS)
	var fade_n := raw.size() - loop_n
	var out := raw.slice(0, loop_n)
	for i in fade_n:
		var k := float(i) / fade_n
		out[i] = raw[i] * k + raw[loop_n + i] * (1.0 - k)
	return _wav(out, true)


static func _wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	for v in samples:
		HatchSounds._push(data, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
