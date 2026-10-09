# scripts/documents/paper_stack_handle.gd — JIOH-27: the stack as something
# other things are pressed onto. A date stamp pressed onto the stack stamps
# its top sheet and stays in hand; another stack put onto it goes on top.
class_name PaperStackHandle
extends InsertReceiver


func _init() -> void:
	verbs = Verb.PICK_UP | Verb.EXAMINE | Verb.INSERT
	accepted_tags = [&"date_stamp", &"paper_stack"]
	consume = false
	tags = [&"paper_stack"]
	display_name = "Paperwork"


func stack() -> PaperStack:
	return body() as PaperStack


func keeps_inserted_in_hand(item: Interactable) -> bool:
	return &"date_stamp" in item.tags


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	var item := payload as Interactable
	received.emit(item)
	if &"date_stamp" in item.tags:
		(item.body() as DateStamp).stamp_onto(stack())
	else:
		stack().put_on_top(item.body() as PaperStack)


func held_items() -> Array[Interactable]:
	return []
