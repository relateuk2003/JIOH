# tools/validate_persistent_ids.gd — JIOH-54: every PersistentObject in every
# scene has a non-empty persistent_id and no id appears twice. A collision
# would silently merge two objects' saved state, so this fails the build.
#
#   godot --headless --path . --script res://tools/validate_persistent_ids.gd
extends SceneTree

const SKIP := ["res://.godot", "res://addons", "res://tests"]


func _initialize() -> void:
	var seen := {}  # id -> "scene:node"
	var problems: Array[String] = []
	for path in _scenes("res://"):
		var state := (load(path) as PackedScene).get_state()
		for i in state.get_node_count():
			var script_path := ""
			var id := ""
			for p in state.get_node_property_count(i):
				var prop := state.get_node_property_name(i, p)
				var value: Variant = state.get_node_property_value(i, p)
				if prop == &"script" and value is Script:
					script_path = (value as Script).resource_path
				elif prop == &"persistent_id":
					id = String(value)
			if script_path != "res://scripts/persistence/persistent_object.gd":
				continue
			var where := "%s:%s" % [path, state.get_node_path(i)]
			if id == "":
				problems.append("empty persistent_id at " + where)
			elif seen.has(id):
				problems.append("duplicate persistent_id '%s' at %s and %s" % [id, seen[id], where])
			else:
				seen[id] = where
	for p in problems:
		printerr("validate_persistent_ids: ", p)
	print("validate_persistent_ids: %d ids, %s" % [seen.size(), "OK" if problems.is_empty() else "%d problems" % problems.size()])
	quit(1 if problems.size() > 0 else 0)


func _scenes(dir: String) -> Array[String]:
	var out: Array[String] = []
	for skip in SKIP:
		if dir.begins_with(skip):
			return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scenes(dir.path_join(d)))
	return out
