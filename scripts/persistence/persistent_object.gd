# scripts/persistence/persistent_object.gd — JIOH-54: marks a prop whose
# position, container and state survive quitting.
#
# Add as a child named "PersistentObject" of any prop the player can move.
# persistent_id is authored and stable, never generated from a node path;
# tools/validate_persistent_ids.gd fails the build on a duplicate or blank id.
class_name PersistentObject
extends Node

## Emitted after a restore applies saved per-object state.
signal state_restored(state: Dictionary)

@export var persistent_id: StringName = &""
## Free-form per-object state (a mug's stained flag, a bin's fill level).
## Systems write here; ObjectRegistry guarantees it round-trips.
var state: Dictionary = {}


func _ready() -> void:
	ObjectRegistry.register(self)


func _exit_tree() -> void:
	ObjectRegistry.unregister(self)


func body() -> Node3D:
	return get_parent() as Node3D


## Records a state change and asks for an autosave.
func set_state(key: String, value: Variant) -> void:
	state[key] = value
	ObjectRegistry.record(self)
