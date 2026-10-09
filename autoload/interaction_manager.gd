# autoload/interaction_manager.gd — JIOH-50: owns the interaction ray, the
# current target, the single carry slot and the event stream.
#
# The player registers its InteractionRay; each physics frame the manager
# resolves what is under it and highlights it. use() picks the verb from
# context (pick up, place, insert, open); examine() is its own input. Every
# outcome goes out as a signal carrying the object, so audio (JIOH-8) and
# persistence (JIOH-54) subscribe without this system knowing they exist.
extends Node

signal target_changed(from: Interactable, to: Interactable)
signal interaction_performed(interactable: Interactable, verb: int)
signal interaction_refused(interactable: Interactable, reason: String)
signal carry_changed(item: Interactable)
signal examine_changed(item: Interactable)
## Insert, from the inserted item's side: item went into receiver.
signal inserted(item: Interactable, receiver: InsertReceiver)

const REACH := 2.0

var ray: RayCast3D
var player: PlayerController
var target: Interactable = null
var carried_item: Interactable = null
var examined_item: Interactable = null
## Where the ray hits a placeable surface, if it does.
var place_point: Variant = null
var place_normal := Vector3.UP

var _examine_restore: Dictionary = {}


func register_player(p: PlayerController) -> void:
	player = p
	ray = p.get_node("Head/Eye/InteractionRay")
	ray.target_position = Vector3(0, 0, -REACH)


func _physics_process(_delta: float) -> void:
	if ray == null or not is_instance_valid(ray):
		return
	ray.force_raycast_update()
	var hit := ray.get_collider() if ray.is_colliding() else null
	var next := hit as Interactable
	if examined_item:
		next = null
	place_point = null
	if hit and not hit is Interactable and ray.get_collision_normal().y > 0.7:
		place_point = ray.get_collision_point()
		place_normal = ray.get_collision_normal()
	_set_target(next)


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed(&"use"):
		use()
	elif event.is_action_pressed(&"examine"):
		examine()
	elif examined_item and event is InputEventMouseMotion \
			and Input.is_action_pressed(&"examine"):
		rotate_examined(event.relative)


## The primary verb, resolved from what is held and what is targeted.
func use() -> void:
	if examined_item:
		return
	if carried_item:
		if target and target.has_verb(Interactable.Verb.INSERT):
			perform(target, Interactable.Verb.INSERT, carried_item)
		elif target and target.has_verb(Interactable.Verb.PICK_UP):
			_refuse(target, "hands_full")
		elif place_point != null:
			perform(carried_item, Interactable.Verb.PLACE, place_point)
		elif target:
			perform(target, Interactable.Verb.OPEN)
		return
	if target == null:
		return
	if target.has_verb(Interactable.Verb.PICK_UP):
		perform(target, Interactable.Verb.PICK_UP)
	elif target.has_verb(Interactable.Verb.OPEN):
		perform(target, Interactable.Verb.OPEN)
	else:
		perform(target, Interactable.Verb.PICK_UP)  # yields a specific refusal


## Examines the carried item, else the target. Pressing again exits.
func examine() -> void:
	if examined_item:
		_end_examine()
		return
	var item := carried_item if carried_item else target
	if item == null:
		return
	var reason := item.can_interact(Interactable.Verb.EXAMINE)
	if reason != "":
		_refuse(item, reason)
		return
	_begin_examine(item)


## Runs one verb against one object, with all the bookkeeping. Public so
## scripted sequences and tests use the same path as the player.
func perform(item: Interactable, verb: Interactable.Verb, payload: Variant = null) -> bool:
	if verb == Interactable.Verb.PICK_UP and carried_item:
		_refuse(item, "hands_full")
		return false
	var reason := item.can_interact(verb, payload)
	if reason != "":
		_refuse(item, reason)
		return false
	match verb:
		Interactable.Verb.PICK_UP:
			_pick_up(item)
		Interactable.Verb.PLACE:
			_place(item, payload)
		Interactable.Verb.INSERT:
			var put := payload as Interactable
			_drop_carry()
			item.interact(verb, put)
			inserted.emit(put, item)
		_:
			item.interact(verb, payload)
	interaction_performed.emit(item, verb)
	return true


func rotate_examined(relative: Vector2) -> void:
	var b := examined_item.body()
	b.rotate_y(relative.x * 0.01)
	b.rotate_object_local(Vector3.RIGHT, relative.y * 0.01)


func _pick_up(item: Interactable) -> void:
	item.interact(Interactable.Verb.PICK_UP)
	item.set_highlighted(false)
	item.set_targetable(false)
	item.body().reparent(player.get_node("Head/Eye/CarryAnchor"), false)
	item.body().transform = Transform3D.IDENTITY
	carried_item = item
	carry_changed.emit(item)


func _place(item: Interactable, point: Vector3) -> void:
	var props := _props_root()
	item.body().reparent(props, false)
	var yaw := player.global_rotation.y
	item.body().global_transform = Transform3D(Basis(Vector3.UP, yaw), point)
	item.set_targetable(true)
	item.interact(Interactable.Verb.PLACE, point)
	carried_item = null
	carry_changed.emit(null)


func _drop_carry() -> void:
	if carried_item:
		carried_item = null
		carry_changed.emit(null)


func _begin_examine(item: Interactable) -> void:
	var b := item.body()
	_examine_restore = {"parent": b.get_parent(), "transform": b.transform,
		"index": b.get_index(), "targetable": item.collision_layer != 0}
	item.set_highlighted(false)
	item.set_targetable(false)
	b.reparent(player.get_node("Head/Eye/ExamineAnchor"), false)
	b.transform = Transform3D.IDENTITY
	examined_item = item
	player.set_movement_locked(true)
	item.interact(Interactable.Verb.EXAMINE)
	interaction_performed.emit(item, Interactable.Verb.EXAMINE)
	examine_changed.emit(item)


func _end_examine() -> void:
	var item := examined_item
	var b := item.body()
	var parent: Node = _examine_restore.parent
	b.reparent(parent, false)
	parent.move_child(b, _examine_restore.index)
	b.transform = _examine_restore.transform
	item.set_targetable(_examine_restore.targetable)
	examined_item = null
	player.set_movement_locked(false)
	examine_changed.emit(null)


func _set_target(next: Interactable) -> void:
	if next == target:
		return
	var prev := target
	if prev and is_instance_valid(prev):
		prev.set_highlighted(false)
	target = next
	if next:
		next.set_highlighted(true)
	target_changed.emit(prev, next)


func _refuse(item: Interactable, reason: String) -> void:
	interaction_refused.emit(item, reason)


## Placed props live under the level's "Props" node, else the player's parent.
func _props_root() -> Node:
	var scene := player.get_parent()
	var props := scene.find_child("Props", true, false)
	return props if props else scene
