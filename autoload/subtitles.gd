# autoload/subtitles.gd — spoken lines. There is no lipsync, so a line's in
# and out timing carries the delivery: a gap between two lines is a real
# pause. The text is a PixelText inside the internal low-resolution viewport
# (JIOH-63), so it is quantised and upscaled with the world like every other
# word in the game; the render stack attaches it at startup.
extends Node

signal line_shown(speaker: StringName, text: String, seconds: float)

var history: Array[Dictionary] = []
var label: PixelText
var _until := 0.0
var _clock := 0.0


## Puts the subtitle line into a viewport (the internal one). Until then
## lines are recorded but drawn nowhere.
func attach(viewport: Viewport) -> void:
	if label and is_instance_valid(label):
		label.get_parent().queue_free()
	var layer := CanvasLayer.new()
	layer.name = "Subtitles"
	layer.layer = 20
	viewport.add_child(layer)
	label = PixelText.new()
	label.ink = Color(0.93, 0.92, 0.86)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vs := viewport.get_visible_rect().size
	label.position = Vector2(roundi(vs.x * 0.08), roundi(vs.y - 34))
	label.size = Vector2(roundi(vs.x * 0.84), 30)
	layer.add_child(label)


## How long a line stays up at a speaker's pace.
static func seconds_for(text: String, words_per_minute: float) -> float:
	var words := text.split(" ", false).size()
	return maxf(1.2, words / maxf(words_per_minute, 60.0) * 60.0 + 0.6)


func say(speaker: StringName, text: String, seconds: float) -> void:
	history.append({"speaker": speaker, "text": text, "seconds": seconds})
	if label and is_instance_valid(label):
		label.text = text
	_until = _clock + seconds
	line_shown.emit(speaker, text, seconds)


func clear() -> void:
	if label and is_instance_valid(label):
		label.text = ""


func _process(delta: float) -> void:
	_clock += delta
	if label and is_instance_valid(label) and label.text != "" and _clock >= _until:
		label.text = ""
