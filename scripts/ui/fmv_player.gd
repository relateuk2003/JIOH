# scripts/ui/fmv_player.gd — JIOH-52: the one thing that plays video.
#
# Instanced when a clip is wanted and gone when it ends. It takes the
# screen, black and letterboxed at the internal 320x240 so the bars scale
# with everything else, and takes the player's hands: no movement, no look,
# no interaction, the mouse let go. The world does not stop. WorldClock and
# DayPhase run and signal throughout; anything that would show itself
# during the clip (a knock at the hatch) can hand its visible part to
# FMVPlayer.defer and it plays when the video is gone. At the end the player
# is exactly where they were, looking exactly where they looked.
#
# A clip already seen is skippable from its first frame by holding Escape
# for a second. A tap does nothing; a first view plays through unless the
# caller says it may be skipped.
class_name FMVPlayer
extends CanvasLayer

signal fmv_started(id: StringName)
signal fmv_finished(id: StringName)
signal fmv_skipped(id: StringName)

const SCENE := "res://scenes/ui/fmv_player.tscn"
const SCREEN := Vector2i(320, 240)
const HOLD_TO_SKIP := 1.0
const DUCK_DB := -14.0
## A clip still "playing" this long past its own length, or whose picture
## has not moved for this long unpaused, is treated as finished. With no
## audio device a Theora clip with sound never reports its end, and no day
## may be held hostage by a video.
const STALL_SECONDS := 3.0
const OVERRUN_SECONDS := 1.0

## The clip playing now, if any. Systems ask this rather than hold a
## reference: the player is never resident.
static var current: FMVPlayer = null
static var _deferred: Array[Callable] = []

var id: StringName = &""
var can_skip := false
var hold := 0.0
var backing: ColorRect
var video: VideoStreamPlayer
var captions: Control
var skip_meter: ColorRect

var _saved: Dictionary = {}
var _office_db := 0.0
var _last_position := -1.0
var _stalled := 0.0


## Puts a new player in the viewport that `host` draws into.
static func spawn(host: Node) -> FMVPlayer:
	var p := (load(SCENE) as PackedScene).instantiate() as FMVPlayer
	host.get_viewport().add_child(p)
	return p


## Runs `effect` now, or when the clip playing now has gone.
static func defer(effect: Callable) -> void:
	if current and is_instance_valid(current) and current.is_playing():
		_deferred.append(effect)
	else:
		effect.call()


func _ready() -> void:
	layer = 100
	backing = ColorRect.new()
	backing.name = "Backing"
	backing.color = Color.BLACK
	backing.size = Vector2(SCREEN)
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backing)
	video = VideoStreamPlayer.new()
	video.name = "Video"
	video.bus = &"FMV"
	video.expand = true
	video.finished.connect(_on_finished)
	add_child(video)
	captions = Control.new()
	captions.name = "Captions"
	captions.size = Vector2(SCREEN)
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(captions)
	skip_meter = ColorRect.new()
	skip_meter.name = "SkipMeter"
	skip_meter.color = Color(0.8, 0.8, 0.8)
	skip_meter.position = Vector2(SCREEN.x - 44, SCREEN.y - 6)
	skip_meter.size = Vector2(0, 2)
	skip_meter.visible = false
	add_child(skip_meter)
	visible = false


func play(stream_path: String, skippable: bool) -> void:
	id = StringName(stream_path.get_file().get_basename())
	can_skip = skippable or CampaignState.has_viewed_fmv(id)
	CampaignState.mark_fmv_viewed(id)
	video.stream = load(stream_path) as VideoStream
	_fit(SCREEN)
	_take_player()
	_duck(true)
	current = self
	visible = true
	hold = 0.0
	video.play()
	fmv_started.emit(id)


func stop() -> void:
	if is_playing():
		_end(false)


func is_playing() -> bool:
	return visible and video != null and video.is_playing()


## The video's rect: the source aspect, as large as fits, on whole pixels.
static func letterbox(source: Vector2i, screen: Vector2i = SCREEN) -> Rect2i:
	if source.x <= 0 or source.y <= 0:
		return Rect2i(Vector2i.ZERO, screen)
	var s := minf(float(screen.x) / source.x, float(screen.y) / source.y)
	var size := Vector2i(floori(source.x * s), floori(source.y * s))
	return Rect2i((screen - size) / 2, size)


func _fit(source: Vector2i) -> void:
	var r := letterbox(source)
	video.position = Vector2(r.position)
	video.size = Vector2(r.size)


func _process(delta: float) -> void:
	if not visible:
		return
	# The source size is known once the first frame is decoded.
	var tex := video.get_video_texture()
	if tex and tex.get_size() != Vector2.ZERO and Vector2i(tex.get_size()) != Vector2i(video.size):
		_fit(Vector2i(tex.get_size()))
	if not video.paused:
		var length := video.get_stream_length()
		if length > 0.0 and video.stream_position > length + OVERRUN_SECONDS:
			_end(false)
			return
		if is_equal_approx(video.stream_position, _last_position):
			_stalled += delta
			if _stalled >= STALL_SECONDS:
				_end(false)
				return
		else:
			_stalled = 0.0
		_last_position = video.stream_position
	if can_skip and Input.is_action_pressed(&"release_mouse"):
		hold += delta
		skip_meter.visible = true
		skip_meter.size.x = roundf(40.0 * minf(hold / HOLD_TO_SKIP, 1.0))
		if hold >= HOLD_TO_SKIP:
			_end(true)
	else:
		hold = 0.0
		skip_meter.visible = false


## Every key, click and mouse movement stops here while the clip plays.
func _input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not video:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		video.paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		video.paused = false


func _on_finished() -> void:
	if visible:
		_end(false)


func _end(skipped: bool) -> void:
	video.stop()
	visible = false
	_duck(false)
	_give_back_player()
	if current == self:
		current = null
	if skipped:
		fmv_skipped.emit(id)
	else:
		fmv_finished.emit(id)
	var effects := _deferred.duplicate()
	_deferred.clear()
	for e in effects:
		e.call()
	queue_free()


func _take_player() -> void:
	var p := InteractionManager.player
	_saved = {"mouse": Input.mouse_mode}
	if p and is_instance_valid(p):
		_saved.merge({"player": p, "transform": p.global_transform, "head": p.head.rotation,
			"locked": p.movement_locked})
		p.set_movement_locked(true)
		p.velocity = Vector3.ZERO
	InteractionManager.set_blocked(self, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _give_back_player() -> void:
	InteractionManager.set_blocked(self, false)
	var p: PlayerController = _saved.get("player")
	if p and is_instance_valid(p):
		p.global_transform = _saved.transform
		p.head.rotation = _saved.head
		p.velocity = Vector3.ZERO
		p.set_movement_locked(_saved.locked)
	Input.mouse_mode = _saved.get("mouse", Input.MOUSE_MODE_CAPTURED)


## The office's ambience is turned down, not off, for the length of the clip.
func _duck(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Ambience")
	if bus < 0:
		return
	if on:
		_office_db = AudioServer.get_bus_volume_db(bus)
		AudioServer.set_bus_volume_db(bus, _office_db + DUCK_DB)
	else:
		AudioServer.set_bus_volume_db(bus, _office_db)
