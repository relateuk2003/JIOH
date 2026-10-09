# autoload/lodgement_ledger.gd — JIOH-32: the record of what went into which
# pigeon hole, and when the holes are open.
#
# Lodgement is the one irreversible act in the day loop. Posting writes the
# hole and the time into each sheet's provenance and appends to
# CampaignState.lodgement_log; retrieving before the cutoff appends a second
# entry rather than erasing the first, so the fortnight's audit trail is
# honest about second thoughts. Nothing here knows or says whether a pack is
# right: the signals carry no verdict and a wrong hole is accepted like any
# other.
extends Node

signal pack_lodged(trade: StringName, instance_ids: Array[StringName])
signal pack_retrieved(trade: StringName, instance_ids: Array[StringName])
## The flaps come down at the cutoff.
signal lodgement_closed
## The flaps go up when the working day starts.
signal lodgement_opened

## Open only through the working day, 10:00 to the 15:30 cutoff. Derived from
## the phase rather than stored, so a reload can never leave the holes open.
var lodgement_open: bool:
	get:
		return DayPhase.phase == DayPhase.Phase.WORKING


func _ready() -> void:
	DayPhase.phase_changed.connect(_on_phase_changed)


## Records a stack posted into a hole. Returns false once the holes are shut.
func lodge(trade: StringName, docs: Array[DocumentInstance]) -> bool:
	if not lodgement_open:
		return false
	var ids: Array[StringName] = []
	for doc in docs:
		doc.lodge(trade)
		doc.location = CampaignState.Location.LODGED
		CampaignState.add_document(doc)
		ids.append(doc.instance_id)
	_log(&"lodged", trade, ids)
	var today := CampaignState.today_record()
	if not today.is_empty():
		today.lodgements_made += 1
	CampaignState.commit(&"lodged")
	pack_lodged.emit(trade, ids)
	return true


## Records a stack taken back out of a hole. The lodgement entry stays.
func retrieve(trade: StringName, docs: Array[DocumentInstance]) -> bool:
	if not lodgement_open:
		return false
	var ids: Array[StringName] = []
	for doc in docs:
		doc.lodged_in_hole = &""
		doc.lodged_at_unix = 0
		doc.location = CampaignState.Location.DESK
		ids.append(doc.instance_id)
	_log(&"retrieved", trade, ids)
	CampaignState.commit(&"retrieved")
	pack_retrieved.emit(trade, ids)
	return true


## What is in a hole now, in posting order, rebuilt from the log. Sheets that
## have since been collected (JIOH-30) are no longer LODGED and drop out.
func contents_of(trade: StringName) -> Array[DocumentInstance]:
	var order: Array[String] = []
	for entry in CampaignState.lodgement_log:
		if StringName(entry.trade) != trade:
			continue
		for id in entry.ids:
			order.erase(String(id))
			if entry.kind == "lodged":
				order.append(String(id))
	var out: Array[DocumentInstance] = []
	for id in order:
		var doc: DocumentInstance = CampaignState.document_instances.get(StringName(id))
		if doc and doc.location == CampaignState.Location.LODGED and doc.lodged_in_hole == trade:
			out.append(doc)
	return out


func _log(kind: StringName, trade: StringName, ids: Array[StringName]) -> void:
	CampaignState.lodgement_log.append({
		"kind": String(kind),
		"trade": String(trade),
		"ids": PackedStringArray(ids),
		"unix": WorldClock.now_unix(),
		"day": WorldClock.get_campaign_day(),
	})


func _on_phase_changed(from: int, to: int) -> void:
	if to == DayPhase.Phase.WORKING:
		lodgement_opened.emit()
	elif from == DayPhase.Phase.WORKING:
		lodgement_closed.emit()
