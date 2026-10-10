# scripts/office/room_info.gd — JIOH-70: one room of the building, as the
# audio systems know it. Named once, in the room registry.
class_name RoomInfo
extends Resource

## The room's node in the office blockout (its Anchor marker lives under it).
@export var key: StringName = &""
## Floor footprint: centre and size on the x/z plane, metres.
@export var centre := Vector2.ZERO
@export var size := Vector2.ONE
## One of the three era reverb spaces (JIOH-66).
@export var space: StringName = &"Space_hall"
## Wins over an overlapping room with a lower priority (Janice's desk
## inside reception).
@export var priority: int = 0
## Rooms you can hear through a doorway.
@export var neighbours: Array[StringName] = []
## Whether a room tone emitter sits at the room's Anchor.
@export var has_tone: bool = true


func contains(p: Vector3) -> bool:
	return absf(p.x - centre.x) <= size.x / 2.0 and absf(p.z - centre.y) <= size.y / 2.0
