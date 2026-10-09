# scripts/props/stamp_band.gd — JIOH-27: one of the date stamp's three bands.
# Use turns it one detent forward.
class_name StampBand
extends Interactable

var stamp: DateStamp
var band: int = 0


func _init() -> void:
	verbs = Verb.OPEN


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base == "" and not stamp.is_ratchet_free():
		return "stamp_band_still_turning"
	return base


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.OPEN:
		stamp.wind(band as DateStamp.Band)
