# scripts/data/relationship_state.gd — JIOH-21: the per-campaign half of a
# trade. Owned and saved by CampaignState under relationships[trade_id]; what
# makes day 9 different from day 2.
class_name RelationshipState
extends RefCounted

var strikes: int = 0
var goodwill: float = 0.0
var days_since_last_success: int = 0
var has_walked: bool = false
var outstanding_query: StringName = &""


func to_dict() -> Dictionary:
	return {
		"strikes": strikes,
		"goodwill": goodwill,
		"days_since_last_success": days_since_last_success,
		"has_walked": has_walked,
		"outstanding_query": String(outstanding_query),
	}


static func from_dict(d: Dictionary) -> RelationshipState:
	var r := RelationshipState.new()
	r.strikes = int(d.get("strikes", 0))
	r.goodwill = float(d.get("goodwill", 0.0))
	r.days_since_last_success = int(d.get("days_since_last_success", 0))
	r.has_walked = bool(d.get("has_walked", false))
	r.outstanding_query = StringName(d.get("outstanding_query", ""))
	return r
