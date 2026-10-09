# scripts/interaction/hatch_handover_zone.gd — JIOH-30: the counter of the
# hatch, as somewhere a held pack can be pushed. Aim and press: there is no
# auto-transfer on proximity, because the commitment is the point.
class_name HatchHandoverZone
extends InsertReceiver

var handout: HandoutInteraction


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"paper_stack"]
	consume = false
	object_id = &"hatch"
	display_name = "Hatch"


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base != "":
		return base
	if handout == null or not handout.can_take_pack():
		return "hatch_nobody_waiting"
	return ""


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	received.emit(payload)
	handout.take_pack((payload as Interactable).body() as PaperStack)


func held_items() -> Array[Interactable]:
	return []
