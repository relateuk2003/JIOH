# scripts/props/jam_sheet_handle.gd — JIOH-27: the crumpled sheet in a jammed
# printer. Pulling it out (picking it up) is the second step of clearing it.
class_name JamSheetHandle
extends Interactable

var printer: DotMatrixPrinter


func _init() -> void:
	verbs = Verb.PICK_UP | Verb.EXAMINE
	tags = [&"crumpled_paper"]
	display_name = "Crumpled sheet"
	object_id = &"printer_jam_sheet"


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.PICK_UP and printer:
		printer.jam_sheet_pulled()
		printer = null
