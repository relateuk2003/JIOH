# scripts/interaction/field_target.gd — JIOH-23: one box on the sheet in
# front of the player, as something the pen can be put to. Only targetable
# while the pen is in hand, and never highlighted: a box looks the same
# aimed at or not, filled right or wrong.
class_name FieldTarget
extends InsertReceiver

var controller: DeskFillController
var field: DocumentField


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"pen"]
	consume = false


func keeps_inserted_in_hand(_item: Interactable) -> bool:
	return true


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.INSERT:
		controller.activate(field)


func set_highlighted(_on: bool) -> void:
	pass


func held_items() -> Array[Interactable]:
	return []
