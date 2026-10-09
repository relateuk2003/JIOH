# tools/build_room_tone_matrix.gd — JIOH-70: writes the starting room tone
# matrix from the reception column and per-room offsets.
#
#   godot --headless --path . res://tools/build_room_tone_matrix.tscn
#
# A starting point for tuning, not the source of truth: once tuned in the
# inspector, the .tres is what ships. Rerunning this overwrites it.
extends Node

const N := -INF
## Reception, by column: structural, electrical, exterior, incidental.
const RECEPTION := {
	&"closed": [N, N, -30.0, N],
	&"pre_open": [-18.0, -14.0, -26.0, -24.0],
	&"handout": [-22.0, -20.0, -20.0, -26.0],
	&"working": [-24.0, -22.0, -18.0, -26.0],
	&"cutoff": [-26.0, -22.0, -18.0, -26.0],
	&"wind_down": [N, -24.0, -24.0, -28.0],
	&"weekend": [N, N, -30.0, -30.0],
}
## Per room: a dB offset per layer (structural, electrical, exterior, incidental).
const OFFSETS := {
	&"Reception": [0.0, 0.0, 0.0, 0.0],
	&"Hatch": [0.0, 0.0, 6.0, 0.0],
	&"JanicesDesk": [0.0, 0.0, 0.0, 0.0],
	&"Stairwell": [2.0, 0.0, 4.0, 2.0],
	&"FileStore": [-4.0, -4.0, -4.0, -4.0],
	&"PrintRoom": [0.0, 4.0, 0.0, 0.0],
	&"KeyCabinet": [-6.0, -6.0, -6.0, -6.0],
	&"Kitchen": [0.0, 0.0, 0.0, 0.0],
	&"YardDoor": [0.0, 0.0, 8.0, 0.0],
}
const BEDS := {&"structural": &"boiler", &"electrical": &"lights", &"exterior": &"traffic"}
const INCIDENTALS := {
	&"Reception": {&"tick": 2, &"creak": 1, &"thump": 1},
	&"Hatch": {&"thump": 2, &"creak": 1},
	&"JanicesDesk": {&"tick": 1, &"creak": 1},
	&"Stairwell": {&"thump": 2, &"creak": 2, &"tick": 1},
	&"FileStore": {&"creak": 3, &"tick": 2},
	&"PrintRoom": {&"tick": 2, &"creak": 1},
	&"KeyCabinet": {&"creak": 1},
	&"Kitchen": {&"tick": 2, &"thump": 1},
	&"YardDoor": {&"thump": 2, &"creak": 1},
}
## The kitchen fridge runs all night and all weekend.
const FRIDGE_DB := -16.0


func _ready() -> void:
	var m := RoomToneMatrix.new()
	var reg := RoomRegistry.shipped()
	for r in reg.rooms:
		if not r.has_tone:
			continue
		var room := String(r.key)
		var off: Array = OFFSETS.get(r.key, [0.0, 0.0, 0.0, 0.0])
		for col in RoomToneMatrix.COLUMNS:
			var base: Array = RECEPTION[col]
			for li in RoomToneMatrix.LAYERS.size():
				var l := RoomToneMatrix.LAYERS[li]
				var v: float = base[li] + off[li]
				if r.key == &"Kitchen" and l == &"electrical":
					v = FRIDGE_DB
				m.volumes["%s/%s/%s" % [room, col, l]] = v
		for l in BEDS:
			m.beds["%s/%s" % [room, l]] = &"fridge" if r.key == &"Kitchen" and l == &"electrical" else BEDS[l]
		m.incidentals[room] = INCIDENTALS.get(r.key, {&"creak": 1})
	ResourceSaver.save(m, RoomToneMatrix.PATH)
	print("wrote %s (%d entries)" % [RoomToneMatrix.PATH, m.volumes.size()])
	get_tree().quit()
