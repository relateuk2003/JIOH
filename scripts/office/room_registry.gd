# scripts/office/room_registry.gd — JIOH-70: every room, named once. The
# acoustic zones, the room tone emitters and the tone matrix all key on
# these names.
class_name RoomRegistry
extends Resource

const PATH := "res://resources/office/room_registry.tres"

@export var rooms: Array[RoomInfo] = []


static func shipped() -> RoomRegistry:
	return load(PATH) as RoomRegistry


func get_room(key: StringName) -> RoomInfo:
	for r in rooms:
		if r.key == key:
			return r
	return null


func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in rooms:
		out.append(r.key)
	return out


## The room a point is in, highest priority first; &"" outside them all.
func room_at(p: Vector3) -> StringName:
	var best: RoomInfo = null
	for r in rooms:
		if r.contains(p) and (best == null or r.priority > best.priority):
			best = r
	return best.key if best else &""


func are_neighbours(a: StringName, b: StringName) -> bool:
	var ra := get_room(a)
	var rb := get_room(b)
	return (ra != null and b in ra.neighbours) or (rb != null and a in rb.neighbours)
