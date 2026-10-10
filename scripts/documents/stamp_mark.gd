# scripts/documents/stamp_mark.gd — JIOH-18: a date stamp impression.
#
# stamped_date is what the stamp wheel said, not the real date. The wheel is
# set by hand and stays wherever it was left (JIOH-27), so the two disagree
# whenever the player forgets to wind it.
class_name StampMark
extends RefCounted

var stamp_id: StringName = &""
## "YYYY-MM-DD" as printed by the wheel.
var stamped_date: String = ""
## How much ink reached the paper, 0..1. Fades with use; the pad restores it.
var ink_alpha: float = 1.0
## Where the impression landed on the sheet (0..1 sheet space) and its skew.
var position: Vector2 = Vector2(0.75, 0.1)
var rotation_degrees: float = 0.0
var applied_on_day: int = 0
var applied_at_unix: int = 0


static func make(stamp: StringName, wheel_date: String) -> StampMark:
	var m := StampMark.new()
	m.stamp_id = stamp
	m.stamped_date = wheel_date
	m.applied_on_day = WorldClock.get_campaign_day()
	m.applied_at_unix = WorldClock.now_unix()
	return m


func to_dict() -> Dictionary:
	return {"stamp_id": String(stamp_id), "stamped_date": stamped_date,
		"ink_alpha": ink_alpha, "position": [position.x, position.y], "rotation_degrees": rotation_degrees,
		"applied_on_day": applied_on_day, "applied_at_unix": applied_at_unix}


static func from_dict(d: Dictionary) -> StampMark:
	var m := StampMark.new()
	m.stamp_id = StringName(d.get("stamp_id", ""))
	m.stamped_date = String(d.get("stamped_date", ""))
	m.ink_alpha = float(d.get("ink_alpha", 1.0))
	var at: Variant = d.get("position", [0.75, 0.1])
	if at is Array and at.size() == 2:
		m.position = Vector2(float(at[0]), float(at[1]))
	m.rotation_degrees = float(d.get("rotation_degrees", 0.0))
	m.applied_on_day = int(d.get("applied_on_day", 0))
	m.applied_at_unix = int(d.get("applied_at_unix", 0))
	return m
