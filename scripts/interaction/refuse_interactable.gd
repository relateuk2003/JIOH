# scripts/interaction/refuse_interactable.gd — JIOH-43 / JIOH-50: an object
# that answers every verb with a refusal. Janice's desk is one: always
# visible, never opened.
class_name RefuseInteractable
extends Interactable

@export var reason: String = "not_yours"


func _init() -> void:
	verbs = Verb.PICK_UP | Verb.EXAMINE | Verb.OPEN | Verb.INSERT


func can_interact(_verb: Verb, _payload: Variant = null) -> String:
	return reason
