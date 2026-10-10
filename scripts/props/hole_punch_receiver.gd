# scripts/props/hole_punch_receiver.gd — JIOH-27: the punch's mouth. The stack
# goes in and comes back out in hand.
class_name HolePunchReceiver
extends InsertReceiver

var punch: HolePunch


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"paper_stack"]
	consume = false


func keeps_inserted_in_hand(_item: Interactable) -> bool:
	return true


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb == Verb.INSERT:
		received.emit(payload)
		punch.punch_stack((payload as Interactable).body() as PaperStack)


func held_items() -> Array[Interactable]:
	return []
