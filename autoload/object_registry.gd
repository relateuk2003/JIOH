# autoload/object_registry.gd — JIOH-54: where you left it is where it is.
#
# Records the physical arrangement of every PersistentObject: transform,
# parent, container and per-object state. Writes are event-driven (place,
# insert, open, pick up), never polled. Records live in the campaign save
# under world_objects, so the arrangement and the campaign cannot
# desynchronise. restore_all() runs from the level's _ready, before the first
# frame is presented, so nothing visibly pops into place.
#
# The authored scene is the day-one layout: an object with no record stays
# where the scene put it, which is also what a debug reset returns to.
extends Node

var _live: Dictionary = {}  # persistent_id -> PersistentObject
var _level: Node = null


func _ready() -> void:
	InteractionManager.interaction_performed.connect(_on_performed)
	InteractionManager.inserted.connect(_on_inserted)


func register(obj: PersistentObject) -> void:
	_live[obj.persistent_id] = obj


func unregister(obj: PersistentObject) -> void:
	if _live.get(obj.persistent_id) == obj:
		_live.erase(obj.persistent_id)


func get_object(id: StringName) -> PersistentObject:
	return _live.get(id)


## Writes an object's current arrangement into the campaign and commits.
func record(obj: PersistentObject, consumed := false) -> void:
	if _level == null:
		return
	var b := obj.body()
	var container := _container_of(b)
	CampaignState.world_objects[String(obj.persistent_id)] = {
		"transform": b.transform,
		"parent_path": String(_level.get_path_to(b.get_parent())),
		"container_id": String(container),
		"state": obj.state.duplicate(true),
		"last_moved_day": WorldClock.get_campaign_day(),
		"consumed": consumed,
	}
	CampaignState.commit(&"object")


## Puts every persistent object back where its record says, before the first
## frame. Containers are restored before their contents.
func restore_all(level: Node) -> void:
	_level = level
	var records := CampaignState.world_objects
	var pending := _live.keys()
	pending.sort_custom(func(a, b): return _depth(records.get(String(a), {})) < _depth(records.get(String(b), {})))
	for id in pending:
		var rec: Dictionary = records.get(String(id), {})
		if rec.is_empty():
			continue
		var obj: PersistentObject = _live[id]
		if rec.get("consumed", false):
			obj.body().queue_free()
			continue
		var parent: Node = null
		if rec.container_id != "" and _live.has(StringName(rec.container_id)):
			var holder: Node3D = (_live[StringName(rec.container_id)] as PersistentObject).body()
			var receiver := holder.get_node_or_null("Interactable") as InsertReceiver
			parent = receiver.contents if receiver and receiver.contents else holder
		else:
			parent = level.get_node_or_null(NodePath(rec.parent_path))
		if parent == null:
			push_warning("ObjectRegistry: no parent %s for %s" % [rec.parent_path, id])
			continue
		obj.body().reparent(parent, false)
		obj.body().transform = rec.transform
		if rec.container_id != "":
			obj.body().visible = false
			var it := obj.body().get_node_or_null("Interactable") as Interactable
			if it:
				it.set_targetable(false)
		obj.state = (rec.state as Dictionary).duplicate(true)
		obj.state_restored.emit(obj.state)


func _on_performed(item: Interactable, verb: int) -> void:
	if verb in [Interactable.Verb.PLACE, Interactable.Verb.OPEN, Interactable.Verb.PICK_UP]:
		var obj := _persistent_of(item)
		if obj:
			record(obj)


func _on_inserted(item: Interactable, receiver: InsertReceiver) -> void:
	# A stamp pressed on a pad is still in hand; there is nothing to record.
	if receiver.keeps_inserted_in_hand(item):
		return
	var obj := _persistent_of(item)
	if obj:
		record(obj, receiver.consume)


func _persistent_of(item: Interactable) -> PersistentObject:
	if item == null or not is_instance_valid(item):
		return null
	return item.body().get_node_or_null("PersistentObject") as PersistentObject


## The persistent_id of the nearest persistent ancestor, if the body is inside
## another persistent object (a form in a folder).
func _container_of(b: Node) -> StringName:
	var n := b.get_parent()
	while n and n != _level:
		var p := n.get_node_or_null("PersistentObject") as PersistentObject
		if p:
			return p.persistent_id
		n = n.get_parent()
	return &""


func _depth(rec: Dictionary) -> int:
	return 0 if rec.get("container_id", "") == "" else 1
