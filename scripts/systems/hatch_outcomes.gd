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
static func no_handout(trade_id: StringName, day: int) -> void:
	var r := CampaignState.get_relationship(trade_id)
	r.strikes += 1
	r.days_since_last_success += 1
	mark(trade_id, day, "no_handout")
	CampaignState.commit(&"no_handout", true)


static func no_show(trade_id: StringName, day: int) -> void:
	mark(trade_id, day, "no_show")


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
