# scripts/levels/office_level.gd — the playable office: the building, the
# player, lights and the Props root that placed objects live under.
extends Node3D

@onready var office: Node3D = $Office
@onready var player: PlayerController = $Player


func _ready() -> void:
	# Until the front end and consent screen exist (JIOH-48), launching the
	# office resumes slot 1 or stamps a new campaign. The slice (JIOH-82)
	# stamps one already on day 3.
	if not CampaignState.has_campaign() and not CampaignState.resume():
		if SliceBootstrap.enabled():
			SliceBootstrap.seed()
		else:
			CampaignState.new_campaign()
	DayPhase.resync()
	ObjectRegistry.restore_all(self)
	# Props whose contents live in the campaign rather than in world_objects
	# (the pigeon holes) rebuild themselves now.
	get_tree().call_group(&"campaign_restorable", &"restore_from_campaign")
	var anchor := office.get_node("PlayerDesk/Anchor") as Marker3D
	player.global_position = anchor.global_position
	player.rotation.y = anchor.global_rotation.y
