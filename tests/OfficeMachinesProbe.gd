# tests/OfficeMachinesProbe.gd — JIOH-27 acceptance criteria: the date stamp,
# the hole punch and the dot matrix printer, in the office.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D
var im
var refused: Array = []
var stamped: Array = []
var states: Array = []
var completed: Array = []
var printer_refusals: Array = []
var cleared := 0
var crunched: Array = []


func _ready() -> void:
	im = InteractionManager
	use_fake_clock(WED_2026_10_07, 10, 0)
	CampaignState.new_campaign()
	_load_level()
	im.interaction_refused.connect(func(_i, r): refused.append(r))
	await _frames(2)
	await _test_stamp()
	await _test_punch()
	await _test_printer()
	await _test_persistence()
	finish()


func _load_level() -> void:
	level = LEVEL.instantiate()
	add_child(level)
	var stamp := _stamp()
	stamp.document_stamped.connect(func(id, d): stamped.append([id, d]))
	var printer := _printer()
	printer.printer_state_changed.connect(func(_a, b): states.append(b))
	printer.print_completed.connect(func(id): completed.append(id))
	printer.print_refused.connect(func(r): printer_refusals.append(r))
	printer.printer_jam_cleared.connect(func(): cleared += 1)
	(level.get_node("Props/HolePunch") as HolePunch).punch_crunched.connect(func(ids): crunched.append(ids))


func _stamp() -> DateStamp:
	return level.get_node("Props/DateStamp")


func _printer() -> DotMatrixPrinter:
	return level.get_node("Props/DotMatrixPrinter")


# --- Date stamp ---------------------------------------------------------------

func _test_stamp() -> void:
	var stamp := _stamp()
	check(stamp.wheel_date() == "2026-10-01", "day one: the wheels read 1 Oct, from before Janice left (got %s)" % stamp.wheel_date())
	var labels := [stamp.get_node("BandLabel_0").text, stamp.get_node("BandLabel_1").text, stamp.get_node("BandLabel_2").text]
	check(labels == ["01", "OCT", "26"], "and the bands show it: %s" % [labels])

	# Stamp a two-sheet pack with the stale wheel.
	var pack := _stack([&"job_sheet", &"permit_to_work"], Vector3(9.6, 0.76, 3.6))
	var first := pack.documents[0]
	var second := pack.documents[1]
	im.perform(stamp.handle, Interactable.Verb.PICK_UP)
	check(im.carried_item == stamp.handle, "the stamp is picked up")
	refused.clear()
	im.perform(pack.interactable, Interactable.Verb.INSERT, im.carried_item)
	check(first.stamp != null and first.stamp.stamped_date == "2026-10-01",
		"the impression carries the wheel date, not today's (%s)" % WorldClock.date_string(WED_2026_10_07))
	check(im.carried_item == stamp.handle and refused.is_empty(), "the stamp stays in hand and nothing complains")
	check(pack.top() == second, "the stamped sheet slides under; the next press stamps the next sheet")
	im.perform(pack.interactable, Interactable.Verb.INSERT, im.carried_item)
	check(second.stamp != null and second.stamp.ink_alpha < first.stamp.ink_alpha,
		"ink fades with use (%.2f then %.2f)" % [first.stamp.ink_alpha, second.stamp.ink_alpha])
	im.perform(level.get_node("Props/InkPad").receiver, Interactable.Verb.INSERT, im.carried_item)
	check(is_equal_approx(stamp.ink(), 1.0) and im.carried_item == stamp.handle, "the pad re-inks it, still in hand")
	check(stamped.size() == 2 and stamped[0] == [first.instance_id, "2026-10-01"], "document_stamped carries id and wheel date")

	# The validator sees it the next morning at the hatch.
	var job := JobRecord.new()
	job.job_number = "J1"
	job.trade = &"electrician"
	job.start_day = 1
	var only: Array[DocumentInstance] = [first]
	var verdict := PackValidator.score(only, job, 1)
	check(verdict.has(Failure.Code.WRONG_DATE_ON_STAMP), "the stale stamp is a WRONG_DATE_ON_STAMP at handout")

	# Put it back down and wind the day band to today: six detents.
	im.perform(stamp.handle, Interactable.Verb.PLACE, Vector3(9.75, 0.75, 4.08))
	var day_band: StampBand = stamp.bands[DateStamp.Band.DAY]
	refused.clear()
	check(im.perform(day_band, Interactable.Verb.OPEN), "use on the day band turns it")
	im.perform(day_band, Interactable.Verb.OPEN)
	check(refused == ["stamp_band_still_turning"] and stamp.wheel().day == 2,
		"an immediate second turn is refused while the ratchet clicks home")
	var frames := 0
	while stamp.wheel().day < 7:
		await _frames(1)
		frames += 1
		if stamp.is_ratchet_free():
			im.perform(day_band, Interactable.Verb.OPEN)
	check(stamp.wheel_date() == "2026-10-07", "wound to today")
	check(frames / 60.0 >= 2.0, "winding five more days took real time (%.1f s)" % (frames / 60.0))
	im.perform(stamp.handle, Interactable.Verb.PICK_UP)
	var fresh := _stack([&"job_sheet"], Vector3(9.6, 0.76, 3.6))
	im.perform(fresh.interactable, Interactable.Verb.INSERT, im.carried_item)
	check(fresh.top().stamp.stamped_date == "2026-10-07", "now it stamps today")
	im.perform(stamp.handle, Interactable.Verb.PLACE, Vector3(9.75, 0.75, 4.08))
	# Months and days wrap; impossible dates print as they stand.
	for i in 31:
		while not stamp.is_ratchet_free():
			await _frames(1)
		stamp.wind(DateStamp.Band.DAY)
	check(stamp.wheel().day == 7, "the day band wraps after 31")


# --- Hole punch ---------------------------------------------------------------

func _test_punch() -> void:
	var punch: HolePunch = level.get_node("Props/HolePunch")
	var pack := _stack([&"job_sheet", &"rams"], Vector3(9.6, 0.76, 3.6))
	refused.clear()
	im.perform(pack.interactable, Interactable.Verb.PICK_UP)
	im.perform(punch.receiver, Interactable.Verb.INSERT, im.carried_item)
	check(pack.documents.all(func(d): return d.punched and not d.torn), "two sheets come out punched")
	check(im.carried_item == pack.interactable, "and back in hand")
	im.perform(pack.interactable, Interactable.Verb.PLACE, Vector3(9.6, 0.76, 3.6))
	var fat := _stack([&"job_sheet", &"rams", &"rams", &"rams", &"rams", &"rams", &"rams"], Vector3(9.6, 0.76, 3.9))
	im.perform(fat.interactable, Interactable.Verb.PICK_UP)
	im.perform(punch.receiver, Interactable.Verb.INSERT, im.carried_item)
	check(fat.documents.all(func(d): return d.torn and not d.punched), "seven at once: the punch crunches and tears the lot")
	check(crunched.size() == 1 and crunched[0].size() == 7, "punch_crunched carries the torn sheets")
	im.perform(fat.interactable, Interactable.Verb.PLACE, Vector3(9.6, 0.76, 3.9))


# --- Printer ------------------------------------------------------------------

func _test_printer() -> void:
	var printer := _printer()
	check(printer.state == DotMatrixPrinter.State.IDLE and printer.paper_remaining() == DotMatrixPrinter.PAPER_BOX,
		"a full box and an idle printer on day one")
	printer.jam_chance_override = 0.0
	var docs_before := CampaignState.document_instances.size()
	check(printer.print_blank(&"permit_to_work"), "a blank starts printing")
	var authored := printer.seconds_left()
	check(authored >= 9.0 and authored <= 14.0, "it will take 9 to 14 seconds (%.1f)" % authored)
	check(not printer.print_blank(&"rams") and printer_refusals.back() == &"printer_busy", "a second print is refused")
	refused.clear()
	im.perform(printer.lid, Interactable.Verb.OPEN)
	check(refused == ["printer_busy"] and not printer.lid_open, "the lid will not lift mid-print")
	var frames := 0
	while printer.state == DotMatrixPrinter.State.PRINTING:
		await _frames(1)
		frames += 1
	check(absf(frames / 60.0 - authored) < 0.1, "it ran its whole authored duration (%.2f s)" % (frames / 60.0))
	check(completed.size() == 1 and printer.output_stack != null \
		and printer.output_stack.top().doc_id() == &"permit_to_work" \
		and printer.output_stack.top().location == CampaignState.Location.PRINTER_TRAY,
		"the blank lies in the output tray")
	check(printer.paper_remaining() == DotMatrixPrinter.PAPER_BOX - 1, "one sheet of paper used")

	# A jam, cleared by hand.
	printer.jam_chance_override = 1.0
	printer.print_blank(&"rams")
	while printer.state == DotMatrixPrinter.State.PRINTING:
		await _frames(1)
	check(printer.state == DotMatrixPrinter.State.JAMMED and printer.jam_sheet != null, "the printer jams")
	check(CampaignState.document_instances.size() == docs_before + 1, "the jammed sheet never became a document")
	check(printer.paper_remaining() == DotMatrixPrinter.PAPER_BOX - 2, "but the paper is gone")
	var jam_handle: Interactable = printer.jam_sheet.get_node("Interactable")
	check(jam_handle.collision_layer == 0, "the crumpled sheet is under the closed lid")
	refused.clear()
	im.perform(printer.feed_knob, Interactable.Verb.OPEN)
	check(refused == ["printer_jam_still_in"], "turning the knob with the jam still in does nothing")
	check(not printer.print_blank(&"rams"), "nothing prints while jammed")
	im.perform(printer.lid, Interactable.Verb.OPEN)
	check(printer.lid_open and jam_handle.collision_layer != 0, "lift the lid: the crumpled sheet can be reached")
	im.perform(jam_handle, Interactable.Verb.PICK_UP)
	check(im.carried_item == jam_handle and CampaignState.machines.jam_stage == "pulled", "pull it out")
	im.perform(jam_handle, Interactable.Verb.PLACE, Vector3(28.4, 0.76, 0.6))
	refused.clear()
	im.perform(printer.feed_knob, Interactable.Verb.OPEN)
	check(refused == ["printer_lid_open"], "the knob will not re-feed with the lid up")
	im.perform(printer.lid, Interactable.Verb.OPEN)
	im.perform(printer.feed_knob, Interactable.Verb.OPEN)
	check(printer.state == DotMatrixPrinter.State.IDLE and cleared == 1, "close the lid, turn the knob: idle again")
	printer.jam_chance_override = 0.0

	# Out of paper, and the spare box.
	var box: Interactable = level.get_node("Props/SparePaperBox/Interactable")
	im.perform(box, Interactable.Verb.PICK_UP)
	refused.clear()
	im.perform(printer.paper_tray, Interactable.Verb.INSERT, im.carried_item)
	check(refused == ["printer_tray_not_empty"] and im.carried_item == box, "the spare box will not go into a tray with paper in")
	CampaignState.machines.paper_remaining = 0
	printer_refusals.clear()
	check(not printer.print_blank(&"job_sheet"), "an empty tray refuses to print")
	check(printer.state == DotMatrixPrinter.State.OUT_OF_PAPER and printer_refusals == [&"printer_out_of_paper"],
		"a physical refusal and a state change, no message")
	im.perform(printer.paper_tray, Interactable.Verb.INSERT, im.carried_item)
	check(printer.paper_remaining() == DotMatrixPrinter.PAPER_BOX and printer.state == DotMatrixPrinter.State.IDLE,
		"loading the spare box gets it going again")
	await _frames(2)
	check(not is_instance_valid(box) and CampaignState.world_objects.get("spare_paper_box", {}).get("consumed", false),
		"the box is used up, for good")

	# A worn ribbon prints faint, then nothing.
	CampaignState.machines.ribbon_life = 0.1
	printer.print_blank(&"job_sheet")
	while printer.state == DotMatrixPrinter.State.PRINTING:
		await _frames(1)
	var faint: DocumentInstance = printer.output_stack.top()
	check(faint.print_quality < 1.0 and faint.print_quality >= DotMatrixPrinter.FAINTEST,
		"a worn ribbon prints faint but legible (%.2f)" % faint.print_quality)
	CampaignState.machines.ribbon_life = 0.0
	check(not printer.print_blank(&"job_sheet") and printer.state == DotMatrixPrinter.State.OUT_OF_RIBBON,
		"a dead ribbon prints nothing")
	CampaignState.machines.ribbon_life = 1.0
	printer.state = DotMatrixPrinter.State.IDLE

	# Taking the printout off the tray.
	var out := printer.output_stack
	check(out.documents.size() == 2, "both printouts are in the tray")
	im.perform(out.interactable, Interactable.Verb.PICK_UP)
	check(printer.output_stack == null and out.documents.all(func(d): return d.location == CampaignState.Location.DESK),
		"picked up, they are the player's")
	im.perform(out.interactable, Interactable.Verb.PLACE, Vector3(28.6, 0.76, 0.9))


# --- Across a quit --------------------------------------------------------------

func _test_persistence() -> void:
	var printer := _printer()
	printer.jam_chance_override = 1.0
	printer.print_blank(&"rams")
	while printer.state == DotMatrixPrinter.State.PRINTING:
		await _frames(1)
	var stamp := _stamp()
	while not stamp.is_ratchet_free():
		await _frames(1)
	stamp.wind(DateStamp.Band.MONTH)  # day 4's wind, left alone
	var wheel := stamp.wheel_date()
	CampaignState.commit(&"probe", true)
	level.queue_free()
	await _frames(2)
	CampaignState.clear()
	set_local(THU_2026_10_08, 9, 0)
	check(CampaignState.resume(), "the save loads the next day")
	_load_level()
	await _frames(2)
	check(_stamp().wheel_date() == wheel, "the stamp still shows yesterday's wind (%s)" % wheel)
	check(_printer().state == DotMatrixPrinter.State.JAMMED and _printer().jam_sheet != null,
		"and the printer is still jammed")
	check(level.get_node_or_null("Props/SparePaperBox") == null or level.get_node("Props/SparePaperBox").is_queued_for_deletion(),
		"and the spare box has not come back")


func _stack(doc_ids: Array, at: Vector3) -> PaperStack:
	var docs: Array[DocumentInstance] = []
	for id in doc_ids:
		var d := DocumentRegistry.print_document(id)
		CampaignState.add_document(d)
		docs.append(d)
	var s := PaperStack.make(docs)
	level.get_node("Props").add_child(s)
	s.global_position = at
	return s


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
