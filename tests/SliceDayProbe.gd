# tests/SliceDayProbe.gd — JIOH-82: the slice as one working day, end to end.
# Day 3 of a campaign that began on Monday 5 October; the clock is driven
# from 06:30 to 18:00 the way the debug offset drives it, headless.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")
const P := DayPhase.Phase
const R := ReactionResolver.Reaction
var DAY3 := MON_2026_10_05 + 2

var level: Node3D
var hatch: HandoutInteraction
var dressing: PhaseDressing
var phases: Array = []
var seeded: Array[StringName] = []


func _ready() -> void:
	remove_test_saves()
	DayPhase.phase_changed.connect(func(_f, t): phases.append(t))
	await _test_seed_and_morning()
	await _test_full_day_with_restores()
	await _test_quit_mid_form()
	await _test_absent_morning()
	finish()


# --- The seeded morning, played -------------------------------------------

func _test_seed_and_morning() -> void:
	use_fake_clock(DAY3, 6, 30)
	CampaignState.clear()
	var calls := PackValidator.calls
	seeded = SliceBootstrap.seed()
	check(WorldClock.get_campaign_day() == 3 and DayPhase.phase == P.PRE_OPEN, "the slice opens on day 3, at pre-open")
	check(seeded.size() == 2, "two packs from the previous evening are seeded (%s)" % [seeded])
	var right := LodgementLedger.contents_of(seeded[0])
	var wrong := LodgementLedger.contents_of(seeded[1])
	check(not right.is_empty() and not wrong.is_empty() and right.all(func(d): return d.raised_on_day == 2),
		"both sit lodged in their holes, raised on day 2")
	check(HatchOutcomes.is_settled(1) and HatchOutcomes.is_settled(2), "days 1 and 2 are behind us")
	check(PackValidator.calls == calls, "seeding scores nothing")
	# Only the two seeded trades come, so the counter is theirs.
	for id in TradeRoster.shipped().ids():
		if not id in seeded:
			CampaignState.get_relationship(id).has_walked = true
	CampaignState.commit(&"probe", true)
	await _load_level()
	check(dressing.applied == P.PRE_OPEN, "the office is dressed for pre-open")

	# Handout. The wrong pack looks like any other pack, all the way to the hatch.
	set_local(DAY3, 7, 30)
	await _frames(2)
	check(dressing.applied == P.HANDOUT, "07:30: dressed for handout")
	_stand_at_hatch()
	var served := []
	var straddled := false
	var guard := 0
	while served.size() < 2 and guard < 600:
		guard += 1
		if hatch.current == null:
			advance(60)
			await _frames(2)
			continue
		# Someone is walking up or saying good morning: let them, in real frames.
		if hatch.state != HandoutInteraction.State.AWAITING_PACK:
			await _frames(20)
			continue
		var trade := hatch.current.data.trade_id
		var hole: PigeonHole = level.get_node("PigeonHoleWall").holes[trade]
		var before := PackValidator.calls
		Subtitles.history.clear()
		InteractionManager.perform(hole, Interactable.Verb.PICK_UP)
		var held := InteractionManager.carried_item
		check(held != null and PackValidator.calls == before and Subtitles.history.is_empty(),
			"%s's pack comes out of the hole and nothing is scored or said" % trade)
		_stand_at_hatch()
		InteractionManager.perform(hatch.zone, Interactable.Verb.INSERT, held)
		check(PackValidator.calls == before + 1, "it is scored once, as it crosses the hatch")
		if served.size() == 1:
			# The second read straddles 10:00: the boundary must wait for it.
			set_local(DAY3, 10, 0)
			await _frames(1)
			straddled = true
			check(DayPhase.phase == P.WORKING and hatch.is_mid_exchange() and dressing.applied == P.HANDOUT,
				"10:00 passes mid-exchange: the phase changes, the room waits")
		await _until_departing()
		served.append(trade)
		if straddled:
			check(dressing.applied == P.WORKING and not dressing.pending(),
				"the exchange finished uninterrupted and the room changed straight after")
	check(served.size() == 2, "both seeded trades were served (%s)" % [served])
	var ok := HatchOutcomes.reaction(seeded[0], 3)
	var bad := HatchOutcomes.reaction(seeded[1], 3)
	check(ok.get("reaction") == "accepted", "the right pack is accepted (%s)" % [ok])
	check(bad.get("reaction") in ["queried", "refused", "walked"] and bad.get("fault") == "WRONG_JOB_NUMBER",
		"the wrong one fails at the hatch, on its job number (%s)" % [bad])
	await _close()


# --- 06:30 to 18:00, saved and restored at every boundary -------------------

func _test_full_day_with_restores() -> void:
	use_fake_clock(DAY3, 6, 30)
	CampaignState.clear()
	seeded = SliceBootstrap.seed()
	await _load_level()
	phases.clear()
	var seen_at_hatch := 0
	var boundaries := [
		[7, 30, P.HANDOUT], [10, 0, P.WORKING], [15, 30, P.CUTOFF], [16, 30, P.WIND_DOWN], [18, 0, P.CLOSED]]
	var minute := 6 * 60 + 30
	for b in boundaries:
		var target: int = b[0] * 60 + b[1]
		while minute < target:
			minute = mini(minute + 10, target)
			set_local(DAY3, minute / 60, minute % 60)
			await _frames(2)
			seen_at_hatch = maxi(seen_at_hatch, _trades_in_building())
		check(DayPhase.phase == b[2] and dressing.applied == b[2],
			"%02d:%02d: %s, and the room is dressed for it" % [b[0], b[1], DayPhase.phase_name(b[2])])
		var before := _world()
		CampaignState.commit(&"probe", true)
		await _close()
		CampaignState.clear()
		check(CampaignState.resume(), "the save at %02d:%02d loads" % [b[0], b[1]])
		await _load_level()
		var after := _world()
		check(after == before, "restored at %02d:%02d to the same world" % [b[0], b[1]])
		if before != after:
			print("  before: ", before, "\n  after:  ", after)
		check(dressing.applied == b[2], "and dressed for %s on relaunch" % DayPhase.phase_name(b[2]))
	check(phases == [P.HANDOUT, P.WORKING, P.CUTOFF, P.WIND_DOWN, P.CLOSED], "the phases came in order, once each (%s)" % [phases])
	check(seen_at_hatch > 0, "trades came to the hatch in the morning (%d at once)" % seen_at_hatch)
	check(_trades_in_building() == 0, "and by evening every one of them has gone")
	var slots := (level.get_node("ArrivalScheduler") as ArrivalScheduler).build_day_schedule(3)
	check(not slots.is_empty() and slots.all(func(s): return HatchOutcomes.status(s.trade_id, 3) == "no_handout"),
		"nobody served them, so every arrival is recorded as gone without a pack")
	await _close()


# --- Quit with a half-written form ------------------------------------------

func _test_quit_mid_form() -> void:
	use_fake_clock(DAY3, 11, 0)
	CampaignState.clear()
	SliceBootstrap.seed()
	await _load_level()
	var desk: DeskFillController = level.get_node("DeskFill")
	var doc := DocumentRegistry.print_document(&"job_sheet")
	desk.place(PaperStack.make([doc]))
	var pen: Interactable = level.get_node("Props/Pen/Interactable")
	InteractionManager.perform(pen, Interactable.Verb.PICK_UP)
	var fields := doc.template.fields.filter(func(f): return f.type == DocumentField.FieldType.TEXT)
	desk.activate(fields[0])
	desk.type_char("2")
	desk.type_char("0")
	desk.activate(fields[1])
	for ch in "PLAN":
		desk.type_char(ch)
	# Closing the window, mid-word.
	CampaignState.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	var id := doc.instance_id
	await _close()
	CampaignState.clear()
	advance(40 * 60)
	check(CampaignState.resume(), "the save loads forty minutes later")
	await _load_level()
	check(WorldClock.local_minute_of_day(WorldClock.now_unix()) == 11 * 60 + 40, "the office is at 11:40, not 11:00")
	desk = level.get_node("DeskFill")
	var back: DocumentInstance = CampaignState.document_instances.get(id)
	check(back != null and back.location == CampaignState.Location.DESK and desk.document() == back,
		"the form is on the desk")
	check(back.get_value(fields[0].key) == "20" and back.get_value(fields[1].key) == "PLAN",
		"exactly as written, the half-typed box included (%s, %s)" % [back.get_value(fields[0].key), back.get_value(fields[1].key)])
	await _close()


# --- Away for the morning ---------------------------------------------------

func _test_absent_morning() -> void:
	use_fake_clock(DAY3, 7, 0)
	CampaignState.clear()
	seeded = SliceBootstrap.seed()
	await _load_level()
	CampaignState.commit(&"probe", true)
	await _close()
	CampaignState.clear()
	set_local(DAY3, 12, 30)
	check(CampaignState.resume(), "back at 12:30")
	await _load_level()
	check(_trades_in_building() == 0, "the morning's trades have been and gone")
	var slots := (level.get_node("ArrivalScheduler") as ArrivalScheduler).build_day_schedule(3)
	check(slots.all(func(s): return HatchOutcomes.status(s.trade_id, 3) == "no_handout" \
		and not HatchOutcomes.wait_record(s.trade_id, 3).is_empty()), "each one's wait is recorded")
	check(seeded.all(func(t): return not LodgementLedger.contents_of(t).is_empty()),
		"and the packs left for them are still in their holes, uncollected")
	await _close()


# ---------------------------------------------------------------------------

## What a restore must bring back: phase, holes, the hatch, the desk.
func _world() -> Dictionary:
	var holes := {}
	for t in TradeRoster.shipped().ids():
		var c := LodgementLedger.contents_of(t)
		if not c.is_empty():
			holes[String(t)] = c.map(func(d): return String(d.instance_id))
	return {
		"phase": DayPhase.phase,
		"day": WorldClock.get_campaign_day(),
		"holes": holes,
		"hatch": CampaignState.today_record().get("hatch", {}).duplicate(),
		"settled": HatchOutcomes.is_settled(3),
		"notes": HatchOutcomes.notes_on_counter().map(func(n): return n.id),
		"docs": CampaignState.document_instances.size(),
		"strikes": TradeRoster.shipped().ids().map(func(t): return CampaignState.get_relationship(t).strikes),
	}


func _trades_in_building() -> int:
	return hatch.find_children("*", "Tradesperson", true, false).filter(
		func(t): return not t.is_queued_for_deletion()).size()


func _until_departing() -> void:
	var n := 0
	while hatch.is_mid_exchange() and n < 400:
		advance(1)
		await _frames(2)
		n += 1


func _load_level() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	hatch = level.get_node("Hatch")
	dressing = level.get_node("PhaseDressing")
	await _frames(2)


func _close() -> void:
	level.queue_free()
	await _frames(2)


func _stand_at_hatch() -> void:
	level.player.global_position = Vector3(6.8, 0, 3.625)
	level.player.rotation.y = PI / 2


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
