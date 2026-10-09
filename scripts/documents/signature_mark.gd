# scripts/documents/signature_mark.gd — JIOH-18: a signature on a sheet.
class_name SignatureMark
extends RefCounted

## Who signed: &"player", a trade id, or a named character.
var signer: StringName = &""
var signed_on_day: int = 0
var signed_at_unix: int = 0


static func make(by: StringName) -> SignatureMark:
	var m := SignatureMark.new()
	m.signer = by
	m.signed_on_day = WorldClock.get_campaign_day()
	m.signed_at_unix = WorldClock.now_unix()
	return m


func to_dict() -> Dictionary:
	return {"signer": String(signer), "signed_on_day": signed_on_day,
		"signed_at_unix": signed_at_unix}


static func from_dict(d: Dictionary) -> SignatureMark:
	var m := SignatureMark.new()
	m.signer = StringName(d.get("signer", ""))
	m.signed_on_day = int(d.get("signed_on_day", 0))
	m.signed_at_unix = int(d.get("signed_at_unix", 0))
	return m
