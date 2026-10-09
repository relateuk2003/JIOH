# tests/RoomToneProbe.gd — JIOH-70 acceptance criteria, in the office.
# Emitters are stepped by hand (advance) so twenty-second fades and five
# minutes of incidentals run in a few frames.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var zones: AcousticZones


func _ready() -> void:
	use_fake_clock(WED_2026_10_07, 7, 0)
	CampaignState.new_campaign()
	level = LEVEL.instantiate()
	add_child(level)
	zones = level.get_node("AcousticZones")
	await _frames(3)
	for e in RoomTone.emitters.values():
		(e as RoomToneEmitter).set_process(false)
	var reg := RoomRegistry.shipped()
	var toned := reg.rooms.filter(func(r): return r.has_tone).map(func(r): return r.key)
	check(RoomTone.emitters.keys().size() == toned.size() and toned.all(func(k): return RoomTone.emitters.has(k)),
		"one emitter per room with tone (%d)" % toned.size())
	var all_ambience := RoomTone.emitters.values().all(func(e):
		return e.get_children().filter(func(c): return c is AudioStreamPlayer3D).all(func(p): return p.bus == &"Ambience"))
	check(all_ambience, "every room tone player is on the Ambience bus")
	var m := RoomTone.matrix
	check(m.incidental_min_gap == 45.0 and m.incidental_ceiling_db == -6.0 and m.crossfade_seconds == 20.0,
		"gap, ceiling and crossfade are tunable on the matrix")

	# Reception at 07:00 (pre-open: the heating has just come on).
	var rec: RoomToneEmitter = RoomTone.emitters[&"Reception"]
	check(RoomTone.current_column() == &"pre_open", "07:00 is the pre-open column")
	var morning := _levels(rec)
	check(rec.layers[&"structural"].playing and is_equal_approx(morning[&"structural"], -18.0),
		"07:00: the boiler is up in reception (%s)" % [morning])

	# To 16:00, through the day's phases: a twenty-second crossfade.
	set_local(WED_2026_10_07, 16, 0)
	await _frames(2)
	check(RoomTone.current_column() == &"cutoff" and rec.fading(), "16:00 is cutoff, and reception starts to fade")
	var amp_from := db_to_linear(rec.layer_db(&"structural"))
	var amp_to := db_to_linear(rec.target_db(&"structural"))
	var worst_step := 0.0
	var prev := amp_from
	var steps := 0
	while rec.fading() and steps < 100:
		rec.advance(0.5)
		var a := db_to_linear(rec.layer_db(&"structural"))
		worst_step = maxf(worst_step, absf(a - prev))
		prev = a
		steps += 1
	check(steps == 40, "the crossfade takes twenty seconds (%d half-second steps)" % steps)
	check(worst_step <= absf(amp_to - amp_from) / 40.0 * 1.01, "no step in it bigger than its even share (%.5f)" % worst_step)
	var afternoon := _levels(rec)
	check(afternoon != morning and is_equal_approx(afternoon[&"structural"], -26.0) and is_equal_approx(afternoon[&"exterior"], -18.0),
		"16:00 sounds different from 07:00 (%s)" % [afternoon])

	# Off means off: at wind-down the boiler player stops.
	set_local(WED_2026_10_07, 16, 30)
	await _frames(2)
	for i in 41:
		rec.advance(0.5)
	check(is_inf(m.db(&"Reception", &"wind_down", &"structural")) and not rec.layers[&"structural"].playing,
		"a -INF layer is stopped, not playing quietly")
	check(rec.layers[&"electrical"].playing, "while the lights stay on")

	# Saturday: no heating, no lights, except the fridge.
	set_local(SAT_2026_10_10, 11, 0)
	await _frames(2)
	check(RoomTone.current_column() == &"weekend", "Saturday is the weekend column")
	_settle_all()
	var silent := true
	for room in RoomTone.emitters:
		var e: RoomToneEmitter = RoomTone.emitters[room]
		for l in [&"structural", &"electrical"]:
			if room == &"Kitchen" and l == &"electrical":
				continue
			if e.layers.has(l) and e.layers[l].playing:
				silent = false
	check(silent, "Saturday: structural and electrical silent in every room")
	var kitchen: RoomToneEmitter = RoomTone.emitters[&"Kitchen"]
	check(kitchen.layers[&"electrical"].playing and is_equal_approx(kitchen.layer_db(&"electrical"), -16.0),
		"except the kitchen fridge")

	# Back to a working day; walk from the print room to the stairwell.
	set_local(SAT_2026_10_10 + 2, 11, 0)  # Monday
	await _frames(2)
	_settle_all()
	var printer: RoomToneEmitter = RoomTone.emitters[&"PrintRoom"]
	zones.update_player_room(Vector3(29, 1, 2.75))
	check(RoomTone.player_room == &"PrintRoom" and printer.cutoff_hz() >= RoomToneEmitter.OPEN_HZ, "in the print room its tone is open")
	var print_space := zones.space_at(Vector3(29, 1, 2.75))
	zones.update_player_room(Vector3(14, 1, -2))
	check(RoomTone.player_room == &"Stairwell", "the player is now in the stairwell")
	check(printer.layers[&"electrical"].playing and printer.cutoff_hz() < 3000.0,
		"the print room behind is low-passed (%.0f Hz), not cut" % printer.cutoff_hz())
	var stair: RoomToneEmitter = RoomTone.emitters[&"Stairwell"]
	check(stair.cutoff_hz() >= RoomToneEmitter.OPEN_HZ, "the stairwell's own tone is open")
	check(zones.space_at(Vector3(14, 1, -2)) != print_space, "and the reverb changes (%s to %s)" % [print_space, zones.space_at(Vector3(14, 1, -2))])
	zones.update_player_room(Vector3(11, 1, 4))
	var rec_n := RoomTone.emitters[&"Stairwell"] as RoomToneEmitter
	check(rec_n.cutoff_hz() > printer.cutoff_hz(), "next door is less muffled than further away")

	# Five minutes in the file store: sparse incidentals under the bed.
	var store: RoomToneEmitter = RoomTone.emitters[&"FileStore"]
	zones.update_player_room(Vector3(21, 1, 2.75))
	store.fired.clear()
	for i in 1200:
		store.advance(0.25)
	var gaps_ok := true
	var under := true
	for i in store.fired.size():
		var f: Array = store.fired[i]
		if f[1] > f[2] + m.incidental_ceiling_db + 0.01:
			under = false
		if i > 0 and f[0] - store.fired[i - 1][0] < m.incidental_min_gap - 0.01:
			gaps_ok = false
	check(store.fired.size() >= 1 and store.fired.size() <= 6, "a handful of incidentals in five minutes (%d)" % store.fired.size())
	check(gaps_ok, "never two within 45 seconds")
	check(under, "never above the room's bed minus 6 dB")

	# The console override, and back to the clock.
	RoomTone.force_column(&"closed")
	check(RoomTone.current_column() == &"closed" and not rec.layers[&"electrical"].playing, "tone closed: the lights go off at once")
	RoomTone.clear_force()
	check(RoomTone.current_column() == &"working", "tone clock: back to the working day")
	finish()


func _levels(e: RoomToneEmitter) -> Dictionary:
	var out := {}
	for l in e.layers:
		out[l] = e.layer_db(l)
	return out


func _settle_all() -> void:
	for e in RoomTone.emitters.values():
		for i in 42:
			(e as RoomToneEmitter).advance(0.5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
