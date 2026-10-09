# scripts/interaction/interactable.gd — JIOH-50: the one way anything in the
# office is interacted with. Five verbs and no more.
#
# Add as a child (Area3D on the interactable physics layer, with a collision
# shape) of the object it represents. The parent is what gets picked up,
# placed, examined or inserted. Subclasses override can_interact() and
# interact(); refusal is a first-class result with a specific reason, never a
# silent no-op.
class_name Interactable
extends Area3D

enum Verb { PICK_UP = 1, EXAMINE = 2, PLACE = 4, OPEN = 8, INSERT = 16 }

const LAYER_INTERACTABLE := 4  # physics layer 3

## Bit flags over Verb.
@export_flags("Pick up", "Examine", "Place", "Open", "Insert") var verbs: int = Verb.EXAMINE
@export var display_name: String = ""
## Stable id carried by every interaction event. Defaults to the sibling
## PersistentObject's id when there is one (JIOH-54).
@export var object_id: StringName = &""
## What this object is, for insert receivers: &"paper", &"key", &"form"...
@export var tags: Array[StringName] = []
@export var interaction_data: InteractionData


func _ready() -> void:
	# Anything that can be picked up can be put down again.
	if has_verb(Verb.PICK_UP):
		verbs |= Verb.PLACE
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	if object_id == &"":
		var persistent := get_parent().get_node_or_null("PersistentObject")
		object_id = persistent.persistent_id if persistent else StringName(get_parent().name)


func has_verb(verb: Verb) -> bool:
	return verbs & verb != 0


## The node that moves when this is picked up, placed or examined.
func body() -> Node3D:
	return get_parent() as Node3D


## Returns "" if the verb may proceed, or a specific refusal reason.
## payload is the carried Interactable for INSERT, the hit point for PLACE.
func can_interact(verb: Verb, _payload: Variant = null) -> String:
	if not has_verb(verb):
		return "cannot_%s" % Verb.find_key(verb).to_lower()
	return ""


## Performs the verb. Only called after can_interact() returned "".
func interact(_verb: Verb, _payload: Variant = null) -> void:
	pass


## Lifts the object's brightness by a fixed step while targeted: a slight
## vertex-colour lift, not an outline or a glow.
func set_highlighted(on: bool) -> void:
	for mesh in _meshes(body()):
		mesh.set_instance_shader_parameter(&"highlight", 1.0 if on else 0.0)


## Stops the interaction ray hitting this while carried.
func set_targetable(on: bool) -> void:
	collision_layer = LAYER_INTERACTABLE if on else 0


static func _meshes(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		out.append(node)
	for c in node.get_children():
		if not c is Interactable:
			out.append_array(_meshes(c))
	return out
