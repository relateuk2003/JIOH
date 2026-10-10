# scripts/props/ink_pad_receiver.gd — JIOH-27: takes the date stamp and gives
# it back inked.
class_name InkPadReceiver
extends InsertReceiver


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"date_stamp"]
	consume = false


func keeps_inserted_in_hand(_item: Interactable) -> bool:
	return true


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb == Verb.INSERT:
		received.emit(payload)
		((payload as Interactable).body() as DateStamp).re_ink()


func held_items() -> Array[Interactable]:
	return []
