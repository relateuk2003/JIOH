# autoload/subtitles.gd — spoken lines, shown at full resolution over the
# PS1 frame. There is no lipsync, so a line's in and out timing carries the
# delivery: a gap between two lines is a real pause. Typed like a works
# docket, not a game HUD.
extends CanvasLayer

signal line_shown(speaker: StringName, text: String, seconds: float)

var history: Array[Dictionary] = []
var _label: Label
var _until := 0.0
var _clock := 0.0


func _ready() -> void:
	layer = 20
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.15
	_label.anchor_right = 0.85
	_label.anchor_top = 0.86
	_label.anchor_bottom = 0.96
	_label.add_theme_color_override(&"font_color", Color(0.93, 0.92, 0.86))
	_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.05))
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_font_size_override(&"font_size", 22)
	add_child(_label)


## How long a line stays up at a speaker's pace.
static func seconds_for(text: String, words_per_minute: float) -> float:
	var words := text.split(" ", false).size()
	return maxf(1.2, words / maxf(words_per_minute, 60.0) * 60.0 + 0.6)


func say(speaker: StringName, text: String, seconds: float) -> void:
	history.append({"speaker": speaker, "text": text, "seconds": seconds})
	_label.text = text
	_until = _clock + seconds
	line_shown.emit(speaker, text, seconds)


func clear() -> void:
	_label.text = ""


func _process(delta: float) -> void:
	_clock += delta
	if _label.text != "" and _clock >= _until:
		_label.text = ""
