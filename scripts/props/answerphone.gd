# scripts/props/answerphone.gd — JIOH-26: the cassette answerphone on the desk.
#
# Play, stop and rewind; no scrubbing, no counter, no transcript. Messages
# left overnight queue on the tape in the order they were left and play
# through one after another. Rewind goes back to the start, and a replay is
# identical, every time: a mumbled name stays mumbled and replaying is a
# real verb.
class_name Answerphone
extends Node3D

signal message_started(message_id: StringName)
signal tape_stopped
signal tape_rewound

## Silence on the tape between messages.
const GAP_SECONDS := 1.0
const MIX_RATE := 11025

var tape: Array[PhoneMessage] = []
var position_s := 0.0
var playing := false
var current: PhoneMessage = null
var player: AudioStreamPlayer3D
var buttons: Dictionary = {}

static var _murmurs: Dictionary = {}  # message_id -> AudioStreamWAV


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	var body := Color(0.14, 0.14, 0.15)
	PropMesh.box(self, "Body", Vector3(0, 0.03, 0), Vector3(0.22, 0.06, 0.16), body)
	PropMesh.box(self, "CassetteWindow", Vector3(0.04, 0.061, -0.02), Vector3(0.09, 0.002, 0.055), Color(0.3, 0.28, 0.25))
	player = AudioStreamPlayer3D.new()
	player.name = "Speaker"
	player.bus = &"Voice"
	player.unit_size = 2.0
	add_child(player)
	for i in 3:
		var action: StringName = [&"play", &"stop", &"rewind"][i]
		var x := -0.07 + i * 0.03
		PropMesh.box(self, "Button_%s" % action, Vector3(x, 0.062, 0.045), Vector3(0.022, 0.006, 0.018),
			[Color(0.2, 0.45, 0.2), Color(0.45, 0.2, 0.2), Color(0.35, 0.35, 0.35)][i])
		var b := AnswerphoneButton.new()
		b.machine = self
		b.action = action
		b.object_id = StringName("answerphone_%s" % action)
		b.display_name = String(action).capitalize()
		PropMesh.handle(self, b, "Button_%s_Interactable" % action, Vector3(x, 0.066, 0.045), Vector3(0.026, 0.012, 0.022))
		buttons[action] = b
	WorldClock.day_rolled.connect(func(_d): load_tape())


func restore_from_campaign() -> void:
	load_tape()


## Puts today's messages on the tape, rewound.
func load_tape() -> void:
	stop()
	tape = InformationBoard.phone_messages_on(WorldClock.get_campaign_day())
	position_s = 0.0


func play() -> void:
	if tape.is_empty() or position_s >= tape_length():
		return
	playing = true
	_cue()


func stop() -> void:
	if not playing:
		return
	playing = false
	current = null
	if player:
		player.stop()
	tape_stopped.emit()


func rewind() -> void:
	stop()
	position_s = 0.0
	tape_rewound.emit()


func tape_length() -> float:
	var total := 0.0
	for m in tape:
		total += m.spoken_seconds() + GAP_SECONDS
	return total


## What is heard for a message: its recording, or a placeholder murmur of
## the same length built from the message id so it never varies.
static func stream_for(m: PhoneMessage) -> AudioStream:
	if m.audio:
		return m.audio
	if not _murmurs.has(m.message_id):
		_murmurs[m.message_id] = _murmur(m)
	return _murmurs[m.message_id]


func _process(delta: float) -> void:
	if not playing:
		return
	position_s += delta
	if position_s >= tape_length():
		position_s = tape_length()
		stop()
		return
	_cue()


# Starts whichever message the tape head is in, if it is not already playing.
func _cue() -> void:
	var t := 0.0
	for m in tape:
		var length := m.spoken_seconds()
		if position_s < t + length:
			if current != m:
				current = m
				player.stream = stream_for(m)
				player.play(position_s - t)
				message_started.emit(m.message_id)
			return
		t += length + GAP_SECONDS
	if current:
		current = null
		player.stop()


static func _murmur(m: PhoneMessage) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(m.message_id)
	var n := int(m.spoken_seconds() * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	var syllable := 0.0
	var pitch := 140.0
	for i in n:
		if syllable <= 0.0:
			syllable = rng.randf_range(0.08, 0.22) * MIX_RATE
			pitch = rng.randf_range(110.0, 180.0)
		syllable -= 1.0
		phase += TAU * pitch / MIX_RATE
		var env := sin(PI * fmod(syllable / (0.15 * MIX_RATE), 1.0))
		var v := (sin(phase) * 0.6 + sin(phase * 2.03) * 0.25 + rng.randf_range(-0.15, 0.15)) * env * 0.5
		data[i] = int(clampf(v, -1.0, 1.0) * 100.0) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
