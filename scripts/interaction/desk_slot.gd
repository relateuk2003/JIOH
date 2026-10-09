# scripts/interaction/desk_slot.gd — JIOH-23: the patch of desk in front of
# the player where paper is laid to be written on. A stack goes in; empty
# hands take the whole stack back out.
class_name DeskSlot
extends InsertReceiver

var controller: DeskFillController


func _init() -> void:
	verbs = Verb.INSERT | Verb.PICK_UP
	accepted_tags = [&"paper_stack"]
	consume = false


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base == "" and verb == Verb.PICK_UP and controller.stack == null:
		return "desk_slot_empty"
	return base


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	received.emit(payload)
	var incoming := (payload as Interactable).body() as PaperStack
	if controller.stack:
		controller.stack.put_on_top(incoming)
		controller.place(controller.stack)
	else:
		controller.place(incoming)


func lifted_by_pick_up() -> Interactable:
	return controller.take().interactable


func held_items() -> Array[Interactable]:
	return []
