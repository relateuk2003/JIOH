# scripts/audio/room_tone_rig.gd — JIOH-70: puts one room tone emitter in
# each room that has tone, at the room's Anchor in the office blockout (or
# up at the ceiling over its centre when it has none), and keeps RoomTone
# told which room the player is in.
class_name RoomToneRig
extends Node3D

const CEILING := 2.4

@export var zones_path: NodePath = ^"../AcousticZones"
@export var office_path: NodePath = ^"../Office"


func _ready() -> void:
	var matrix := RoomToneMatrix.shipped()
	var office := get_node_or_null(office_path)
	for r in RoomRegistry.shipped().rooms:
		if not r.has_tone:
			continue
		var e := RoomToneEmitter.make(r.key, matrix)
		add_child(e)
		var anchor := office.get_node_or_null("%s/Anchor" % r.key) as Node3D if office else null
		e.global_position = anchor.global_position if anchor else Vector3(r.centre.x, CEILING, r.centre.y)
	var zones := get_node_or_null(zones_path) as AcousticZones
	if zones:
		zones.player_room_changed.connect(RoomTone.set_player_room)
		_initial_room.call_deferred(zones)


func _initial_room(zones: AcousticZones) -> void:
	var p := InteractionManager.player
	if p and is_instance_valid(p):
		zones.update_player_room(p.global_position)
