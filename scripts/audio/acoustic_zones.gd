# scripts/audio/acoustic_zones.gd — JIOH-66/70: which of the three spaces
# each part of the building sounds like, and which room the player is in.
#
# One Area3D per room in the room registry, sending any 3D sound made
# inside it to that room's reverb bus. Three spaces and no more: rooms share
# them, as they did on the hardware. Zones sit on their own physics layer
# so the interaction ray never meets them; they watch only the player.
class_name AcousticZones
extends Node3D

signal player_room_changed(room: StringName)

const SPACES: Array[StringName] = [&"Space_small", &"Space_hall", &"Space_dead"]
const HEIGHT := 3.0
const PLAYER_LAYER := 2

var registry: RoomRegistry
var player_room: StringName = &""


func _ready() -> void:
	registry = RoomRegistry.shipped()
	for r in registry.rooms:
		var a := Area3D.new()
		a.name = String(r.key)
		a.collision_layer = EraBus.ZONE_LAYER
		a.collision_mask = PLAYER_LAYER
		a.priority = r.priority
		a.reverb_bus_enabled = true
		a.reverb_bus_name = r.space
		a.reverb_bus_amount = 0.6
		a.reverb_bus_uniformity = 0.2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, HEIGHT, r.size.y)
		shape.shape = box
		a.add_child(shape)
		a.position = Vector3(r.centre.x, HEIGHT / 2.0, r.centre.y)
		a.body_entered.connect(_on_body_moved)
		a.body_exited.connect(_on_body_moved)
		add_child(a)


## The space a point in the building sounds like.
func space_at(p: Vector3) -> StringName:
	var r := registry.get_room(registry.room_at(p))
	return r.space if r else &""


func _on_body_moved(body: Node3D) -> void:
	if body is PlayerController:
		update_player_room(body.global_position)


func update_player_room(at: Vector3) -> void:
	var room := registry.room_at(at)
	if room != player_room:
		player_room = room
		player_room_changed.emit(room)
