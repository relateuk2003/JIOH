# scripts/systems/hatch_sounds.gd — JIOH-37: the knock at the hatch and the
# phone on Janice's desk. Both must carry through walls: until the JIOH-8
# building propagation bus exists they use a long, gentle falloff so a knock
# is heard from the archive. The streams are synthesised placeholders.
class_name HatchSounds
extends Node3D

## On Janice's desk, inside her pen: audible, unreachable.
const PHONE_AT := Vector3(7.35, 0.8, 5.45)
const RATE := 22050

var knock: AudioStreamPlayer3D
var phone: AudioStreamPlayer3D
## What was played, for tests: [cue, knock_style].
var played: Array = []


func _ready() -> void:
	knock = _player("Knock", _knock_stream(), Vector3(0.0, 1.1, 0.0))
	phone = _player("JanicePhone", _ring_stream(), Vector3.ZERO)
	phone.top_level = true
	phone.global_position = PHONE_AT


func play(cue: StringName, style: StringName) -> void:
	played.append([cue, style])
	# During a cutscene the knock is heard when the video has gone.
	FMVPlayer.defer(_sound.bind(cue, style))


func _sound(cue: StringName, style: StringName) -> void:
	match cue:
		&"knock":
			knock.volume_db = -4.0 if style == &"bang" else (-14.0 if style in [&"tap", &"polite"] else -8.0)
			knock.play()
		&"knock_hard":
			knock.volume_db = 0.0
			knock.play()
		&"phone":
			phone.play()


func _player(n: String, stream: AudioStream, at: Vector3) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = stream
	p.position = at
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = 6.0
	p.max_distance = 40.0
	add_child(p)
	return p


static func _knock_stream() -> AudioStreamWAV:
	var data := PackedByteArray()
	for k in 3:
		for i in int(RATE * 0.16):
			var t := float(i) / RATE
			var v := sin(TAU * 95.0 * t) * exp(-t * 38.0) + (randf_noise(i + k * 977) * 0.3) * exp(-t * 90.0)
			_push(data, v * 0.8)
	return _wav(data)


static func _ring_stream() -> AudioStreamWAV:
	# UK ring: 0.4 on, 0.2 off, 0.4 on, 2.0 off, twice.
	var data := PackedByteArray()
	for r in 2:
		for seg in [[0.4, true], [0.2, false], [0.4, true], [2.0, false]]:
			for i in int(RATE * seg[0]):
				var t := float(i) / RATE
				_push(data, (sin(TAU * 400.0 * t) + sin(TAU * 450.0 * t)) * 0.3 if seg[1] else 0.0)
	return _wav(data)


## Deterministic noise without the global RNG.
static func randf_noise(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


static func _push(data: PackedByteArray, v: float) -> void:
	var s := clampi(int(v * 32767.0), -32768, 32767)
	data.append(s & 0xFF)
	data.append((s >> 8) & 0xFF)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
