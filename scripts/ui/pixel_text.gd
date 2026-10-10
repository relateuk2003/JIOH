# scripts/ui/pixel_text.gd — JIOH-63: the only text node in the game.
#
# A Label locked to one of the three bitmap faces at a whole-number scale,
# drawn nearest-neighbour and snapped to whole pixels. It lives inside the
# internal low-resolution viewport (or a surface SubViewport), so its pixels
# go through the same quantisation and upscale as the world.
class_name PixelText
extends Label

const SETTINGS := preload("res://resources/fonts/pixel_label_settings.tres")

@export var face: JiohFonts.Face = JiohFonts.Face.BODY:
	set(v):
		face = v
		_apply()
## Whole-number scale only; there is no fractional type size.
@export_range(1, 8) var pixel_scale: int = 1:
	set(v):
		pixel_scale = maxi(v, 1)
		_apply()
@export var ink: Color = Color(0.1, 0.1, 0.1):
	set(v):
		ink = v
		_apply()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_notify_transform(true)
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		var whole := position.round()
		if whole != position:
			position = whole


func _apply() -> void:
	var s := SETTINGS.duplicate() as LabelSettings
	s.font = JiohFonts.font(face)
	s.font_size = JiohFonts.size(face, pixel_scale)
	s.font_color = ink
	label_settings = s
