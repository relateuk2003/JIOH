# scripts/props/hatch_note_handle.gd — JIOH-37: picking a note up off the
# counter is what clears it from the campaign.
class_name HatchNoteHandle
extends Interactable

var note_id := ""


func _init() -> void:
	verbs = Verb.PICK_UP | Verb.EXAMINE
	tags = [&"hatch_note"]
	display_name = "Note"


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.PICK_UP:
		HatchOutcomes.pick_up_note(note_id)
