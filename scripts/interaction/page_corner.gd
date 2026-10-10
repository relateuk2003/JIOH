# scripts/interaction/page_corner.gd — JIOH-23: the corner of the top sheet.
# Use it to slide that sheet under the stack and bring the next one up.
class_name PageCorner
extends Interactable

var controller: DeskFillController


func _init() -> void:
	verbs = Verb.OPEN


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.OPEN:
		controller.turn_page()


func set_highlighted(_on: bool) -> void:
	pass
