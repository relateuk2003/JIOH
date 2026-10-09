# autoload/room_tone.gd — JIOH-70: sets every room's tone for the time of
# day. Listens to the day phase and the calendar, looks each room up in the
# matrix and hands its emitter the mix, crossfaded. Also tells emitters how
# far they are from the player, for occlusion. Knows nothing about what
# the sounds are.
extends Node

signal mix_applied(column: StringName)

var matrix: RoomToneMatrix
var emitters: Dictionary = {}  # room -> RoomToneEmitter
var column: StringName = &""
var player_room: StringName = &""
var _forced: StringName = &""


func _ready() -> void:
	matrix = RoomToneMatrix.shipped()
	DayPhase.phase_changed.connect(func(_f, _t): apply(matrix.crossfade_seconds))
	WorldClock.day_rolled.connect(func(_d): apply(matrix.crossfade_seconds))
	CampaignState.campaign_started.connect(func(): apply(0.0))


func register(e: RoomToneEmitter) -> void:
	emitters[e.room] = e
	_apply_one(e, current_column(), 0.0)
	_occlude(e)


func unregister(e: RoomToneEmitter) -> void:
	if emitters.get(e.room) == e:
		emitters.erase(e.room)


func current_column() -> StringName:
	if _forced != &"":
		return _forced
	return RoomToneMatrix.column_for(DayPhase.phase, EnvironmentState.is_weekend())


## Re-reads the column and fades every room to it.
func apply(seconds: float) -> void:
	column = current_column()
	for e in emitters.values():
		_apply_one(e, column, seconds)
	mix_applied.emit(column)


## Developer override: hear a column without moving the clock.
func force_column(c: StringName, seconds: float = 0.0) -> void:
	_forced = c
	apply(seconds)


func clear_force(seconds: float = 0.0) -> void:
	_forced = &""
	apply(seconds)


func set_player_room(room: StringName) -> void:
	player_room = room
	for e in emitters.values():
		_occlude(e)


## One line per room: what each layer is set to now.
func readout() -> String:
	var lines := PackedStringArray(["column %s, player in %s" % [current_column(), player_room]])
	for room in emitters:
		var e: RoomToneEmitter = emitters[room]
		var parts := PackedStringArray()
		for l in RoomToneMatrix.BEDS:
			if e.layers.has(l):
				var d := e.layer_db(l)
				parts.append("%s %s" % [String(l).left(4), "off" if is_inf(d) else "%.0f" % d])
		lines.append("%s: %s" % [room, ", ".join(parts)])
	return "\n".join(lines)


func _apply_one(e: RoomToneEmitter, c: StringName, seconds: float) -> void:
	e.weekend = c == &"weekend"
	e.set_mix(matrix.mix(e.room, c), seconds)


func _occlude(e: RoomToneEmitter) -> void:
	if player_room == &"" or e.room == player_room:
		e.set_occlusion(0)
	elif RoomRegistry.shipped().are_neighbours(e.room, player_room):
		e.set_occlusion(1)
	else:
		e.set_occlusion(2)
