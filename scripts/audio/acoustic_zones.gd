# scripts/audio/acoustic_zones.gd — JIOH-66: which of the three spaces each
# part of the building sounds like.
#
# One Area3D per room, sending any 3D sound made inside it to one of the
# three reverb buses. Three spaces and no more: rooms share them, as they
# did on the hardware. Zones sit on their own physics layer so the
# interaction ray never meets them.
class_name AcousticZones
extends Node3D

const SPACES: Array[StringName] = [&"Space_small", &"Space_hall", &"Space_dead"]
const HEIGHT := 3.0
## name: [centre x, centre z, size x, size z, space, priority]. Janice's desk
## sits inside reception but is her own dead corner.
const ROOMS := {
	"PrintRoom": [29.0, 2.75, 6.0, 5.5, &"Space_small", 0],
	"FileStore": [21.0, 2.75, 6.0, 5.5, &"Space_small", 0],
	"KeyCabinet": [19.0, 8.25, 2.0, 1.5, &"Space_small", 0],
	"Kitchen": [25.0, 22.5, 10.0, 5.0, &"Space_small", 0],
	"Reception": [11.0, 4.0, 10.0, 8.0, &"Space_hall", 0],
	"Stairwell": [14.0, -2.0, 4.0, 4.0, &"Space_hall", 0],
	"Corridor": [25.0, 6.5, 18.0, 2.0, &"Space_hall", 0],
	"CorridorSouth": [25.0, 13.75, 2.0, 12.5, &"Space_hall", 0],
	"Hatch": [4.0, 4.0, 4.0, 8.0, &"Space_dead", 0],
	"JanicesDesk": [7.0, 5.5, 2.4, 3.0, &"Space_dead", 1],
	"YardDoor": [35.0, 6.5, 2.0, 2.0, &"Space_dead", 0],
}


func _ready() -> void:
	for room in ROOMS:
		var r: Array = ROOMS[room]
		var a := Area3D.new()
		a.name = room
		a.collision_layer = EraBus.ZONE_LAYER
		a.collision_mask = 0
		a.monitoring = false
		a.priority = r[5]
		a.reverb_bus_enabled = true
		a.reverb_bus_name = r[4]
		a.reverb_bus_amount = 0.6
		a.reverb_bus_uniformity = 0.2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r[2], HEIGHT, r[3])
		shape.shape = box
		a.add_child(shape)
		a.position = Vector3(r[0], HEIGHT / 2.0, r[1])
		add_child(a)


## The space a point in the building sounds like, highest priority first.
func space_at(p: Vector3) -> StringName:
	var best: StringName = &""
	var best_priority := -1
	for a in get_children():
		var area := a as Area3D
		var box := (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
		if AABB(area.global_position - box.size / 2.0, box.size).has_point(p) and area.priority > best_priority:
			best = area.reverb_bus_name
			best_priority = int(area.priority)
	return best
