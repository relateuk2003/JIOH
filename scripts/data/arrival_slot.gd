# scripts/data/arrival_slot.gd — JIOH-28: one trade's arrival on one day.
class_name ArrivalSlot
extends RefCounted

var trade_id: StringName = &""
var arrival_unix: int = 0
var patience_expiry_unix: int = 0
## False for a trade turning up with nothing booked (story beats, later).
var expected: bool = true


func equals(o: ArrivalSlot) -> bool:
	return o != null and trade_id == o.trade_id and arrival_unix == o.arrival_unix \
		and patience_expiry_unix == o.patience_expiry_unix and expected == o.expected


func _to_string() -> String:
	return "%s@%d" % [trade_id, arrival_unix]
