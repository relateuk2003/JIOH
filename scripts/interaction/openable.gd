# scripts/interaction/openable.gd — JIOH-50: the open verb. Drawers, cabinet
# doors, the key cabinet, the file store door. Swings or slides a hinge node.
class_name Openable
extends Interactable

signal opened_changed(is_open: bool)

## The node that moves. Defaults to this Interactable's parent.
@export var hinge: Node3D
@export var open_rotation_degrees := Vector3(0, -95, 0)
@export var open_offset := Vector3.ZERO
@export var is_open := false
## Locked objects refuse with this reason (e.g. "key_cabinet_locked").
@export var locked_reason: String = ""

var _closed_transform: Transform3D


func _init() -> void:
	verbs = Verb.OPEN


func _ready() -> void:
	super()
	if hinge == null:
		hinge = body()
	_closed_transform = hinge.transform
	_apply(false)


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base == "" and verb == Verb.OPEN and locked_reason != "":
		return locked_reason
	return base


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.OPEN:
		is_open = not is_open
		_apply(true)
		opened_changed.emit(is_open)


func _apply(animate: bool) -> void:
	var target := _closed_transform
	if is_open:
		target = Transform3D(_closed_transform.basis * Basis.from_euler(open_rotation_degrees * PI / 180.0),
			_closed_transform.origin + open_offset)
	if animate and hinge.is_inside_tree():
		create_tween().tween_property(hinge, "transform", target, 0.25)
	else:
		hinge.transform = target
