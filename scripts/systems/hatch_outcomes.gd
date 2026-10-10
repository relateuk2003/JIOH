# scripts/systems/hatch_outcomes.gd — the write-backs every path through the
# hatch shares. The live morning and absence replay both call these, which is
# what makes a missed morning end the same as a watched one (JIOH-28). The
# reaction resolver (JIOH-34) and waiting behaviour (JIOH-37) build on them.
class_name HatchOutcomes
extends RefCounted


static func status(trade_id: StringName, day: int) -> String:
	return String(_hatch(day).get(String(trade_id), ""))


static func mark(trade_id: StringName, day: int, value: String) -> void:
	var rec := _record(day)
	if rec.is_empty():
		return
	if not rec.has("hatch"):
		rec["hatch"] = {}
	rec.hatch[String(trade_id)] = value
	CampaignState.commit(&"hatch")


## Nobody handed them a pack before their patience ran out. From the trade's
## side an empty hatch costs the same as a broken pack (JIOH-37): a strike.
## The wait is recorded with its stamps, and a note left on the counter if
## the trade writes one (JIOH-37).
static func no_handout(trade_id: StringName, day: int, slot: ArrivalSlot = null, wait: WaitOutcome = null) -> void:
	var r := CampaignState.get_relationship(trade_id)
	r.strikes += 1
	r.days_since_last_success += 1
	mark(trade_id, day, "no_handout")
	var rec := _record(day)
	if slot and not rec.is_empty():
		if not rec.has("waits"):
			rec["waits"] = {}
		rec.waits[String(trade_id)] = {"arrived": slot.arrival_unix,
			"left": wait.departed_unix if wait else slot.patience_expiry_unix}
	if slot and wait and wait.left_note:
		leave_note(trade_id, day, slot.arrival_unix, wait.departed_unix)
	CampaignState.commit(&"no_handout", true)


## When a trade waited and when they gave up, or {} if they did not.
static func wait_record(trade_id: StringName, day: int) -> Dictionary:
	return _record(day).get("waits", {}).get(String(trade_id), {})


## NoteData, kept in world_artefacts until the player picks the note up.
static func leave_note(trade_id: StringName, day: int, arrived_unix: int, left_unix: int) -> void:
	var came_for := "their pack"
	for job in InformationBoard.live_jobs_on(day):
		if job.trade == trade_id:
			came_for = "%s %s" % [job.job_number, job.location]
	CampaignState.world_artefacts.append({
		"kind": "hatch_note",
		"id": "note_%s_%d" % [trade_id, day],
		"trade_id": String(trade_id),
		"day": day,
		"arrived_unix": arrived_unix,
		"left_unix": left_unix,
		"came_for": came_for,
		"picked_up": false,
	})


static func notes_on_counter() -> Array:
	return CampaignState.world_artefacts.filter(func(a): return a is Dictionary and a.get("kind") == "hatch_note" and not a.get("picked_up", false))


static func pick_up_note(note_id: String) -> void:
	for a in CampaignState.world_artefacts:
		if a is Dictionary and a.get("id") == note_id:
			a["picked_up"] = true
	CampaignState.commit(&"note", true)


static func no_show(trade_id: StringName, day: int) -> void:
	mark(trade_id, day, "no_show")


## How the hatch went for a trade (JIOH-34): accepted, refused or walked,
## the fault behind it and whether a query was answered on the spot. Read by
## end-of-day returns and the narrative; never shown as a number.
static func record_reaction(trade_id: StringName, day: int, reaction: String, fault_id: StringName, query_resolved: bool) -> void:
	var rec := _record(day)
	if rec.is_empty():
		return
	if not rec.has("reactions"):
		rec["reactions"] = {}
	rec.reactions[String(trade_id)] = {"reaction": reaction, "fault": String(fault_id), "query_resolved": query_resolved}


static func reaction(trade_id: StringName, day: int) -> Dictionary:
	return _record(day).get("reactions", {}).get(String(trade_id), {})


static func is_settled(day: int) -> bool:
	return bool(_record(day).get("hatch_settled", false))


static func settle(day: int) -> void:
	var rec := _record(day)
	if not rec.is_empty():
		rec["hatch_settled"] = true
		CampaignState.commit(&"hatch_settled", true)


static func _hatch(day: int) -> Dictionary:
	return _record(day).get("hatch", {})


static func _record(day: int) -> Dictionary:
	if day < 1 or day > CampaignState.day_records.size():
		return {}
	return CampaignState.day_records[day - 1]
