# scripts/levels/office_level.gd — the playable office: the building, the
# player, lights and the Props root that placed objects live under.
extends Node3D

@onready var office: Node3D = $Office
@onready var player: PlayerController = $Player


func _ready() -> void:
	ObjectRegistry.restore_all(self)
	var anchor := office.get_node("PlayerDesk/Anchor") as Marker3D
	player.global_position = anchor.global_position
	player.rotation.y = anchor.global_rotation.y
