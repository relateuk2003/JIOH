# scripts/interaction/insert_receiver.gd — JIOH-50: the receiving end of
# insert, the only two-object verb. Paper into the printer, a form into a
# folder, a docket through the hatch.
#
# Accepts only items carrying one of accepted_tags and refuses anything else
# with a reason naming what it wanted. Consumed items are freed; otherwise
# they are parented under contents (a folder keeps its forms).
class_name InsertReceiver
extends Interactable

signal received(item: Interactable)

@export var accepted_tags: Array[StringName] = []
## Free the item on insert (the printer eats paper). Otherwise keep it.
@export var consume: bool = true
## Where kept items go. Defaults to this receiver's parent.
@export var contents: Node3D
## Most items this receiver will hold, or 0 for no limit.
@export var capacity: int = 0


func _init() -> void:
	verbs = Verb.INSERT


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base != "" or verb != Verb.INSERT:
		return base
	var item := payload as Interactable
	if item == null:
		return "insert_nothing_held"
	for t in item.tags:
		if t in accepted_tags:
			if capacity > 0 and held_items().size() >= capacity:
				return "%s_full" % object_id
			return ""
	return "%s_takes_only_%s" % [object_id, "_or_".join(accepted_tags.map(func(t): return String(t)))]


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	var item := payload as Interactable
	received.emit(item)
	if consume:
		item.body().queue_free()
	else:
		var into := contents if contents else body()
		item.body().reparent(into, false)
		item.body().transform = Transform3D(Basis(), Vector3(0, 0.002 * held_items().size(), 0))
		item.body().visible = false
		item.set_targetable(false)


func held_items() -> Array[Interactable]:
	var out: Array[Interactable] = []
	var into := contents if contents else body()
	for child in into.get_children():
		var it := child.get_node_or_null("Interactable") as Interactable
		if it and child != body():
			out.append(it)
	return out
