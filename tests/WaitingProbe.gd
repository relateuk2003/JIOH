# tests/WaitingProbe.gd — JIOH-37 acceptance criteria. Only the gas engineer
# is willing this campaign, and for the probe his patience is ten minutes.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const DAY := 2

var level: Node3D
var hatch: HandoutInteraction
var sched: ArrivalScheduler
var gave_up_at: Array = []
var gas: TradespersonData


func _ready() -> void:
	remove_test_saves()
	gas = TradeRoster.shipped().get_trade(&"gas_engineer")
	gas.patience_seconds = 600.0
	_test_ladders()

	# Left alone the whole time: he goes at arrival + ten minutes, exactly.
	var watched := await _morning_watched()
	var slot: ArrivalSlot = watched.slot
	check(gave_up_at.size() == 1 and gave_up_at[0] == slot.arrival_unix + 600,
		"nobody came: he left at %s, ten minutes after arriving at %s" % [_hhmm(gave_up_at[0] if gave_up_at else 0), _hhmm(slot.arrival_unix)])
	check(HatchOutcomes.wait_record(&"gas_engineer", DAY) == {"arrived": slot.arrival_unix, "left": slot.arrival_unix + 600},
		"the wait is recorded with both stamps")
	var played: Array = hatch.sounds.played.map(func(p): return p[0])
	check(played == [&"knock", &"knock_hard", &"phone"], "he knocked, knocked harder and tried the phone (%s)" % [played])
	check(hatch.sounds.knock.max_distance >= 30.0 and hatch.sounds.phone.global_position.distance_to(HatchSounds.PHONE_AT) < 0.01,
		"the knock carries through the building; the phone rings on Janice's desk")
	var note := _note_node()
	check(note != null and note.global_position.distance_to(Vector3(6.2, 0.978, 3.05)) < 0.05, "a note is left on the counter")
	var words := "\n".join(note.text()) if note else ""
	check(words.contains("Alan") and words.contains(_hm(slot.arrival_unix)) and words.contains(_hm(slot.arrival_unix + 600)),
		"naming him, when he came and when he went:\n%s" % words)
	check(CampaignState.get_relationship(&"gas_engineer").strikes == 1, "a strike, exactly as for a refusal")

	# The player gets there seconds later: gone, and not coming back.
	level.player.global_position = Vector3(6.8, 0, 3.625)
	advance(5)
	await _frames(600)
	check(hatch.current == null and hatch.queue.is_empty() and hatch.get_children().filter(func(c): return c is Tradesperson).is_empty(),
		"seconds later the hatch is empty and he does not return")
	advance(3600)
	await _frames(10)
	check(hatch.current == null and HatchOutcomes.status(&"gas_engineer", DAY) == "no_handout", "not even an hour later")

	# The note stays until it is picked up, across a relaunch.
	CampaignState.commit(&"probe", true)
	await _reload()
	note = _note_node()
	check(note != null, "the note is still on the counter after a relaunch")
	InteractionManager.perform(note.get_node("Interactable"), Interactable.Verb.PICK_UP)
	check(HatchOutcomes.notes_on_counter().is_empty(), "picking it up clears it")
	InteractionManager.perform(InteractionManager.carried_item, Interactable.Verb.PLACE, Vector3(9.5, 0.76, 3.0))
	await _reload()
	check(_note_node() == null, "and it does not come back")
	var watched_state: Dictionary = watched.state

	# The same morning with the game shut from two minutes in until 08:30.
	var missed := await _morning_closed()
	check(missed.wait == HatchOutcomes.wait_record(&"gas_engineer", DAY) and missed.wait.left == slot.arrival_unix + 600,
		"reopened at 08:30: he waited and left at %s" % _hhmm(int(missed.wait.get("left", 0))))
	check(missed.state == watched_state, "the campaign matches the session that stayed open")
	await _close()
	remove_test_saves()
	finish()


func _test_ladders() -> void:
	var scaff := TradeRoster.shipped().get_trade(&"scaffolder")
	var beats := WaitingBehaviour.ladder(scaff, 1000).map(func(b): return b.beat)
	check(not &"phone" in beats and not &"note" in beats and beats.count(&"knock") + beats.count(&"knock_hard") == 2,
		"the scaffolder knocks twice and neither phones nor writes")
	var o := WaitingBehaviour.simulate_to(scaff, 1000, 999999)
	check(o.departed and o.departed_unix == 1000 + int(scaff.patience_seconds) and not o.left_note,
		"and he leaves on the same stamp as anyone with his patience")
	var asb := TradeRoster.shipped().get_trade(&"asbestos_surveyor")
	beats = WaitingBehaviour.ladder(asb, 0).map(func(b): return b.beat)
	check(not &"knock" in beats and not &"knock_hard" in beats and &"note" in beats, "the asbestos surveyor never knocks; she writes")
	var half := WaitingBehaviour.simulate_to(gas, 0, 300)
	check(not half.departed and half.last_beat() == &"knock", "halfway up the ladder he has knocked once")
	var ok := true
	for t in TradeRoster.shipped().trades:
		var first_cue := -1
		for b in WaitingBehaviour.ladder(t, 0):
			if b.beat in [&"knock", &"knock_hard", &"phone"] and first_cue < 0:
				first_cue = b.unix
		ok = ok and (first_cue < 0 or t.patience_seconds - first_cue >= 30)
	check(ok, "every first knock or ring leaves at least thirty seconds to reach the hatch")


func _morning_watched() -> Dictionary:
	await _start()
	var slot: ArrivalSlot = sched.slots[0]
	# Player in the print room the whole time; the clock ticks a second a frame.
	level.player.global_position = Vector3(14.0, 0, 1.0)
	while WorldClock.now_unix() < slot.arrival_unix + 620:
		advance(1)
		await _frames(1)
	return {"slot": slot, "state": _state()}


func _morning_closed() -> Dictionary:
	await _close()
	await _start()
	var slot: ArrivalSlot = sched.slots[0]
	while WorldClock.now_unix() < slot.arrival_unix + 120:
		advance(1)
		await _frames(1)
	CampaignState.commit(&"probe", true)
	await _close()
	CampaignState.clear()
	set_local(SAT_2026_10_10 - 4, 8, 30)  # Tuesday 6 October
	CampaignState.resume()
	await _open()
	await _frames(5)
	return {"wait": HatchOutcomes.wait_record(&"gas_engineer", DAY), "state": _state()}


func _start() -> void:
	gave_up_at.clear()
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	CampaignState.campaign_seed = 77
	for id in TradeRoster.shipped().ids():
		if id != &"gas_engineer":
			CampaignState.get_relationship(id).has_walked = true
	CampaignState.get_day(1).scheduled_trades = []
	CampaignState.get_day(DAY).scheduled_trades = [&"gas_engineer"]
	set_local(MON_2026_10_05 + 1, 7, 29)
	await _open()


func _open() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	hatch = level.get_node("Hatch")
	sched = level.get_node("ArrivalScheduler")
	sched.gave_up.connect(func(s): gave_up_at.append(WorldClock.now_unix()))
	await _frames(2)


func _close() -> void:
	if level:
		level.queue_free()
		level = null
		await _frames(2)


func _reload() -> void:
	await _close()
	CampaignState.clear()
	CampaignState.resume()
	await _open()
	await _frames(3)


## What must come out the same whether the morning was watched or missed.
func _state() -> Dictionary:
	var rec: Dictionary = CampaignState.day_records[DAY - 1]
	return {"relationships": CampaignState.to_dict().relationships, "hatch": rec.get("hatch", {}).duplicate(true),
		"waits": rec.get("waits", {}).duplicate(true),
		"notes": HatchOutcomes.notes_on_counter().map(func(n): return [n.trade_id, n.arrived_unix, n.left_unix])}


func _hm(unix: int) -> String:
	var d := WorldClock.datetime_local(unix)
	return "%d:%02d" % [d.hour, d.minute]


func _note_node() -> HatchNote:
	for c in level.get_node("Props").get_children():
		if c is HatchNote:
			return c
	return null


func _hhmm(unix: int) -> String:
	var d := WorldClock.datetime_local(unix)
	return "%02d:%02d:%02d" % [d.hour, d.minute, d.second]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
