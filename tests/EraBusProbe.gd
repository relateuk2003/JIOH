# tests/EraBusProbe.gd — JIOH-66 acceptance criteria. The headless Dummy
# driver mixes in real time, so the chain is measured live off Master.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var tap: AudioEffectCapture
var tone: AudioStreamPlayer
var gen_playback: AudioStreamGeneratorPlayback
var phase := 0.0


func _ready() -> void:
	use_fake_clock(WED_2026_10_07, 11, 0)
	CampaignState.new_campaign()
	var level: Node3D = LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame

	# Topology: everything through Era; only Monitor skips it.
	var to_master: Array = []
	for i in range(1, AudioServer.bus_count):
		if AudioServer.get_bus_send(i) == &"Master":
			to_master.append(AudioServer.get_bus_name(i))
	check(to_master == ["EraOut", "Monitor"], "only EraOut (Era's tail) and the debug Monitor send to Master (%s)" % [to_master])
	for b in EraBus.SOURCES:
		check(EraBus.route(b).has("Era") and EraBus.route(b)[-1] == "Master", "%s reaches Master through Era" % b)
	var players: Array = []
	_collect_players(level, players)
	var fmv := FMVPlayer.spawn(level)
	_collect_players(fmv, players)
	check(players.size() >= 4 and players.all(func(p): return p.bus in EraBus.SOURCES),
		"every player in the office is on an Era source bus (%d players)" % players.size())
	var stray := AudioStreamPlayer.new()
	add_child(stray)
	check(stray.bus == &"Mechanical", "a player left on Master is routed through Era")
	fmv.queue_free()

	# The ceiling: a 22 kHz mix, low-passed at 11 kHz.
	check(is_equal_approx(AudioServer.get_mix_rate(), 22050.0), "the game mixes at 22050 Hz, so nothing above 11 kHz exists")
	var lp := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Era"), 0) as AudioEffectLowPassFilter
	check(lp != null and lp.cutoff_hz == EraBus.profile.lowpass_hz and lp.cutoff_hz == 11000.0, "Era's low-pass sits at 11 kHz")

	# 8-bit steps and sample hold, measured at Master.
	tap = AudioEffectCapture.new()
	tap.buffer_length = 1.0
	AudioServer.add_bus_effect(0, tap)
	_start_tone()
	var crushed := await _listen(4000)
	check(_on_grid(crushed, 128) > 0.98, "the output sits on 8-bit steps (%.3f on the grid)" % _on_grid(crushed, 128))
	check(_levels(crushed) <= 256 and _peak(crushed) > 0.15, "a real signal, quantised (%d levels)" % _levels(crushed))

	# Bypass: clean and back, live.
	EraBus.set_bypass(true)
	var clean := await _listen(4000)
	check(_on_grid(clean, 128) < 0.5 and _peak(clean) > 0.15, "bypassed, the same tone is clean (%.3f on the grid)" % _on_grid(clean, 128))
	EraBus.set_bypass(false)
	var again := await _listen(4000)
	check(_on_grid(again, 128) > 0.98, "re-enabled, crushed again without a restart")

	# The profile is the tuning: change it and every sound follows.
	EraBus.profile.bit_depth = 4
	EraBus.apply_profile()
	var coarse := await _listen(4000)
	check(_on_grid(coarse, 8) > 0.98 and _levels(coarse) <= 16, "4 bits in the profile gives 4-bit output (%d levels)" % _levels(coarse))
	EraBus.profile.bit_depth = 8
	EraBus.apply_profile()
	tone.stop()

	# A hole punch keeps its anatomy: lever thunk, die click, paper tear.
	var punch := _punch()
	var p2 := AudioStreamPlayer.new()
	p2.bus = &"Mechanical"
	p2.stream = punch
	add_child(p2)
	await _listen(500)
	# Record from a little before the punch so none of it is missed.
	tap.clear_buffer()
	var lead := 0
	while tap.get_frames_available() < 2205 and lead < 4000:
		lead += await _tick()
	p2.play()
	var heard := await _record(int(22050 * 0.75))
	var clean_env := _envelope(_wav_frames(punch))
	var heard_env := _envelope(heard)
	check(_transients(heard_env) == 3 and _transients(clean_env) == 3,
		"the punch is still three events through the chain (%d heard, %d clean)" % [_transients(heard_env), _transients(clean_env)])
	check(_best_correlation(clean_env, heard_env) > 0.85, "and its envelope follows the source (r=%.2f)" % _best_correlation(clean_env, heard_env))

	# Three spaces, no fourth.
	var zones: AcousticZones = level.get_node("AcousticZones")
	check(zones.space_at(Vector3(29, 1, 2.75)) == &"Space_small" and zones.space_at(Vector3(14, 1, -2)) == &"Space_hall",
		"print room to stairwell: small to hall")
	check(zones.space_at(Vector3(7, 1, 5.5)) == &"Space_dead" and zones.space_at(Vector3(11, 1, 2)) == &"Space_hall",
		"Janice's desk is dead inside the reception hall")
	var used := {}
	for a in zones.get_children():
		used[(a as Area3D).reverb_bus_name] = true
	check(used.keys().all(func(b): return b in AcousticZones.SPACES) and used.size() == 3, "every zone uses one of the three spaces")
	var reverbs := _reverb_resources("res://")
	check(reverbs.size() == 3, "exactly three reverb configurations exist in the project (%s)" % [reverbs])
	var layered := zones.get_children().all(func(a): return (a as Area3D).collision_layer == EraBus.ZONE_LAYER)
	check(layered and (InteractionManager.ray.collision_mask & EraBus.ZONE_LAYER) == 0, "and the interaction ray cannot hit a zone")
	finish()


func _start_tone() -> void:
	tone = AudioStreamPlayer.new()
	tone.bus = &"Mechanical"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = AudioServer.get_mix_rate()
	gen.buffer_length = 0.2
	tone.stream = gen
	add_child(tone)
	tone.play()
	gen_playback = tone.get_stream_playback()


func _feed() -> void:
	if tone == null or not tone.playing:
		return
	var n := gen_playback.get_frames_available()
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		buf[i] = Vector2.ONE * (0.3 * sin(phase) + 0.05 * sin(phase * 7.3))
		phase += TAU * 220.0 / AudioServer.get_mix_rate()
	gen_playback.push_buffer(buf)


## Frames off Master once the chain has settled, in real time.
func _listen(frames: int) -> PackedVector2Array:
	# Let what was in flight drain, then take a fresh block.
	var waited := 0
	while waited < 250:
		_feed()
		waited += await _tick()
	tap.clear_buffer()
	waited = 0
	while tap.get_frames_available() < frames and waited < 4000:
		_feed()
		waited += await _tick()
	return tap.get_buffer(mini(frames, tap.get_frames_available()))


## One frame and about a millisecond of real time, so waits are measured
## in the audio thread's time without reading the OS clock (JIOH-14).
func _tick() -> int:
	await get_tree().process_frame
	OS.delay_msec(1)
	return 1


## Frames off Master from now, without settling first.
func _record(frames: int) -> PackedVector2Array:
	var waited := 0
	while tap.get_frames_available() < frames and waited < 4000:
		waited += await _tick()
	return tap.get_buffer(mini(frames, tap.get_frames_available()))


func _on_grid(f: PackedVector2Array, steps: int) -> float:
	var hits := 0
	for v in f:
		if absf(v.x * steps - roundf(v.x * steps)) < 0.02:
			hits += 1
	return float(hits) / maxf(f.size(), 1)


func _held(f: PackedVector2Array) -> float:
	var same := 0
	for i in range(1, f.size()):
		if absf(f[i].x - f[i - 1].x) < 0.001:
			same += 1
	return float(same) / maxf(f.size() - 1, 1)


func _levels(f: PackedVector2Array) -> int:
	var seen := {}
	for v in f:
		seen[roundi(v.x * 1024.0)] = true
	return seen.size()


func _peak(f: PackedVector2Array) -> float:
	var m := 0.0
	for v in f:
		m = maxf(m, absf(v.x))
	return m


## A synthetic punch: a low lever thunk, a sharp die click 60 ms later and
## a short burst of paper 70 ms after that. Authored clean at 48 kHz.
func _punch() -> AudioStreamWAV:
	var rate := 48000
	var data := PackedByteArray()
	for i in int(rate * 0.3):
		var t := float(i) / rate
		var v := 0.0
		v += sin(TAU * 110.0 * t) * exp(-t * 60.0) * 0.6
		if t > 0.06:
			v += sin(TAU * 2400.0 * (t - 0.06)) * exp(-(t - 0.06) * 300.0) * 0.7
		if t > 0.13:
			v += HatchSounds.randf_noise(i) * exp(-(t - 0.13) * 45.0) * 0.4
		HatchSounds._push(data, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _wav_frames(w: AudioStreamWAV) -> PackedVector2Array:
	# Decimated to the mix rate so envelopes line up.
	var out := PackedVector2Array()
	out.resize(int(AudioServer.get_mix_rate() * 0.02))  # a little silence first
	var step := float(w.mix_rate) / AudioServer.get_mix_rate()
	var n := w.data.size() / 2
	var i := 0.0
	while int(i) < n:
		var s := w.data.decode_s16(int(i) * 2) / 32768.0
		out.append(Vector2(s, s))
		i += step
	return out


## 5 ms RMS windows.
func _envelope(f: PackedVector2Array) -> PackedFloat32Array:
	var win := int(AudioServer.get_mix_rate() * 0.005)
	var env := PackedFloat32Array()
	for start in range(0, f.size() - win, win):
		var acc := 0.0
		for j in win:
			acc += f[start + j].x * f[start + j].x
		env.append(sqrt(acc / win))
	return env


## Onsets: the envelope jumping by more than half again in one window, and
## clearing a noise floor, at least 25 ms after the last.
func _transients(env: PackedFloat32Array) -> int:
	var peak := 0.0
	for e in env:
		peak = maxf(peak, e)
	var count := 0
	var last := -100
	for i in range(1, env.size()):
		if env[i] > peak * 0.12 and env[i] > env[i - 1] * 1.5 + peak * 0.02 and i - last >= 5:
			count += 1
			last = i
	return count


var best_lag := 0


func _best_correlation(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var best := -1.0
	for lag in range(0, maxi(b.size() - 10, 0)):
		var n := mini(a.size(), b.size() - lag)
		if n < 10:
			continue
		var ma := 0.0
		var mb := 0.0
		for i in n:
			ma += a[i]
			mb += b[i + lag]
		ma /= n
		mb /= n
		var num := 0.0
		var da := 0.0
		var db := 0.0
		for i in n:
			num += (a[i] - ma) * (b[i + lag] - mb)
			da += (a[i] - ma) * (a[i] - ma)
			db += (b[i + lag] - mb) * (b[i + lag] - mb)
		if da > 0 and db > 0 and num / sqrt(da * db) > best:
			best = num / sqrt(da * db)
			best_lag = lag
	return best


func _collect_players(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			out.append(c)
		_collect_players(c, out)


## Every saved reverb configuration in the project: whole resources and
## embedded ones alike.
func _reverb_resources(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres") or f.ends_with(".tscn"):
			var text := FileAccess.get_file_as_string(dir.path_join(f))
			if text.begins_with("[gd_resource type=\"AudioEffectReverb\""):
				out.append(dir.path_join(f))
			if text.contains("[sub_resource type=\"AudioEffectReverb\""):
				out.append(dir.path_join(f) + " (embedded)")
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_reverb_resources(dir.path_join(d)))
	return out
