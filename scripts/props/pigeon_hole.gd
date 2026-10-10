# scripts/props/pigeon_hole.gd — JIOH-32: one trade's hole in the wall unit.
#
# The Area3D is the mouth of the hole; its parent is the cubby. Posting is
# insert: push the held stack into the mouth and it sits there, visible from
# across the room. Reaching in with empty hands takes the whole lot back out,
# in order, until the cutoff. A wrong hole is accepted exactly like the right
# one: no question, no correction, one sound.
class_name PigeonHole
extends InsertReceiver

@export var trade: StringName = &""
@export var label_text: String = ""

## The stack sitting in the hole, or null.
var stack: PaperStack = null


func _init() -> void:
	verbs = Verb.INSERT | Verb.PICK_UP
	accepted_tags = [&"paper_stack"]
	consume = false


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base != "":
		return base
	if not LodgementLedger.holes_open:
		return "pigeon_holes_closed"
	if verb == Verb.INSERT and not LodgementLedger.lodgement_open:
		return "pigeon_holes_collect_only"
	if verb == Verb.PICK_UP and stack == null:
		return "pigeon_hole_empty"
	return ""


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	var incoming := (payload as Interactable).body() as PaperStack
	var docs := incoming.documents.duplicate()
	LodgementLedger.lodge(trade, docs)
	received.emit(payload)
	if stack:
		stack.add(docs)
		incoming.queue_free()
	else:
		_seat(incoming)


## Empty hands take the whole stack back out: second thoughts through the
## working day, collection for the hatch in the morning.
func lifted_by_pick_up() -> Interactable:
	var s := stack
	stack = null
	if LodgementLedger.lodgement_open:
		LodgementLedger.retrieve(trade, s.documents)
	else:
		LodgementLedger.collect(trade, s.documents)
	s.visible = true
	return s.interactable


## Rebuilds the hole's contents from the campaign (after a load or New Game).
func restore() -> void:
	if stack:
		stack.free()
		stack = null
	var docs := LodgementLedger.contents_of(trade)
	if not docs.is_empty():
		_seat(PaperStack.make(docs))


func held_items() -> Array[Interactable]:
	var out: Array[Interactable] = []
	if stack:
		out.append(stack.interactable)
	return out


func _seat(s: PaperStack) -> void:
	var into := contents if contents else body()
	if s.get_parent():
		s.reparent(into, false)
	else:
		into.add_child(s)
	# Lying flat at the back of the cubby, a corner poking out.
	s.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(4.0)), Vector3(0, 0, -0.02))
	s.visible = true
	s.interactable.set_targetable(false)
	stack = s
