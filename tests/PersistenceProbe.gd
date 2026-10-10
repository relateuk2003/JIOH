# tests/PersistenceProbe.gd — JIOH-54 acceptance criteria. "Relaunch" here
# means: free the level, clear CampaignState, resume from disk, build the
# level again with its props at their authored positions, and restore.
extends Probe

const LEVEL := preload("res://scenes/levels/office_level.tscn")

var level: Node3D


func _ready() -> void:
	remove_test_saves()
	use_fake_clock(MON_2026_10_05, 10, 0)
	CampaignState.new_campaign()
	await _build()
	var im := InteractionManager
	var player: PlayerController = level.player

	# Place a mug on the kitchen worktop.
	var mug := _body("mug")
	im.perform(mug.get_node("Interactable"), Interactable.Verb.PICK_UP)
	im.perform(mug.get_node("Interactable"), Interactable.Verb.PLACE, Vector3(25.3, 0.75, 24.4))
	var mug_xform := mug.global_transform

	# Nine things scattered on the desk across eight days.
	var scattered := {}
	for i in 9:
		set_local(MON_2026_10_05 + i, 11, 0)
		var thing := _body("desk_clutter_%d" % i)
		im.perform(thing.get_node("Interactable"), Interactable.Verb.PICK_UP)
		player.rotation.y = 0.3 * i
		im.perform(thing.get_node("Interactable"), Interactable.Verb.PLACE, Vector3(9.3 + 0.05 * i, 0.75, 3.0 + 0.1 * i))
		scattered[thing.name] = thing.global_transform

	# Three forms into a folder, then the folder to the file store.
	var folder := _body("folder")
	for i in 3:
		var form := _body("form_%d" % i)
		im.perform(form.get_node("Interactable"), Interactable.Verb.PICK_UP)
		im.perform(folder.get_node("Interactable"), Interactable.Verb.INSERT, form.get_node("Interactable"))
	im.perform(folder.get_node("Interactable"), Interactable.Verb.PICK_UP)
	im.perform(folder.get_node("Interactable"), Interactable.Verb.PLACE, Vector3(21.0, 0.0, 2.5))
	var folder_xform := folder.global_transform

	# Nested state written by another system.
	var plant := _body("plant").get_node("PersistentObject") as PersistentObject
	plant.set_state("health", {"leaves": 7, "history": [1.0, 0.8, 0.55]})

	# Quit without a menu.
	CampaignState.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	var raw: Variant = bytes_to_var(FileAccess.get_file_as_bytes(CampaignState.save_path()))
	check(raw is Dictionary and raw.has("world_objects"), "the save written on close parses")

	await _relaunch()
	mug = _body("mug")
	check(mug.global_transform.is_equal_approx(mug_xform), "the mug is where it was left, rotation included")
	var all_there := true
	for n in scattered:
		all_there = all_there and _body(n).global_transform.is_equal_approx(scattered[n])
	check(all_there, "all nine scattered objects are exactly where they were left")
	folder = _body("folder")
	check(folder.global_transform.is_equal_approx(folder_xform), "the folder is in the file store")
	var inside := 0
	for i in 3:
		inside += 1 if _body("form_%d" % i, folder).get_parent() == folder else 0
	check(inside == 3, "all three forms are still inside the folder")
	var st: Dictionary = (_body("plant").get_node("PersistentObject") as PersistentObject).state
	check(st == {"health": {"leaves": 7, "history": [1.0, 0.8, 0.55]}}, "nested object state round-trips")
	check(CampaignState.world_objects["desk_clutter_0"].last_moved_day == 1
		and CampaignState.world_objects["desk_clutter_8"].last_moved_day == 9, "records keep the day each object last moved")
	level.queue_free()
	finish()


func _build() -> void:
	level = LEVEL.instantiate()
	# Authored props, as a dressed scene would have them.
	var props := level.get_node("Props")
	var row := 0
	for id in ["mug", "plant"] + range(9).map(func(i): return "desk_clutter_%d" % i) \
			+ range(3).map(func(i): return "form_%d" % i):
		TestProps.prop(props, id, Vector3(14.0 + 0.3 * (row % 6), 0.0, 1.0 + 0.3 * (row / 6)), [&"form"],
			Interactable.Verb.PICK_UP, true)
		row += 1
	TestProps.receiver(props, "folder", Vector3(15.0, 0.0, 3.0), [&"form"], false, true, true)
	add_child(level)
	await get_tree().physics_frame


func _relaunch() -> void:
	remove_child(level)
	level.free()
	CampaignState.clear()
	check(CampaignState.resume(), "the campaign resumes from disk")
	await _build()


func _body(id: String, under: Node = null) -> Node3D:
	return (under if under else level).find_child(id, true, false) as Node3D
