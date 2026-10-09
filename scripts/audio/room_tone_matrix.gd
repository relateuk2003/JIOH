# scripts/audio/room_tone_matrix.gd — JIOH-70: how loud each layer of each
# room is in each part of the day. A table of dB values keyed
# "Room/column/layer"; -INF is a legal value and means the layer is off,
# genuinely silent, with nothing in its place. Columns are the day phases
# plus "weekend". Built by tools/build_room_tone_matrix and tuned in the
# inspector after that.
class_name RoomToneMatrix
extends Resource

const PATH := "res://resources/audio/room_tone_matrix.tres"
const LAYERS: Array[StringName] = [&"structural", &"electrical", &"exterior", &"incidental"]
const BEDS: Array[StringName] = [&"structural", &"electrical", &"exterior"]
const COLUMNS: Array[StringName] = [&"closed", &"pre_open", &"handout", &"working", &"cutoff", &"wind_down", &"weekend"]

## "Room/column/layer" -> dB.
@export var volumes: Dictionary = {}
## "Room/layer" -> the synthesised bed that layer plays (RoomToneSounds).
@export var beds: Dictionary = {}
## "Room" -> {one-shot kind: weight}.
@export var incidentals: Dictionary = {}
## One-shots never rise above the room's bed by more than this.
@export var incidental_ceiling_db: float = -6.0
@export var incidental_min_gap: float = 45.0
@export var incidental_mean_gap: float = 110.0
## Crossfade between columns, seconds.
@export var crossfade_seconds: float = 20.0


static func shipped() -> RoomToneMatrix:
	return load(PATH) as RoomToneMatrix


func db(room: StringName, column: StringName, layer: StringName) -> float:
	return float(volumes.get("%s/%s/%s" % [room, column, layer], -INF))


func mix(room: StringName, column: StringName) -> Dictionary:
	var out := {}
	for l in LAYERS:
		out[l] = db(room, column, l)
	return out


static func column_for(phase: int, weekend: bool) -> StringName:
	if weekend:
		return &"weekend"
	return COLUMNS[clampi(phase, 0, COLUMNS.size() - 2)]
