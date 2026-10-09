# scripts/props/face_canvas.gd — the Control a PaperFace draws through.
class_name FaceCanvas
extends Control

var face: PaperFace


func _draw() -> void:
	if face and face.painter.is_valid():
		face.painter.call(self)


## Helpers shared by the painters.
func text(at: Vector2, s: String, px: int, col: Color, width: float = -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, at, s, align, width, px, col)


## Marker or biro writing, nudged per glyph like the handwriting on forms.
func hand(at: Vector2, s: String, px: int, col: Color, seed_key: Variant = 0) -> float:
	var font := ThemeDB.fallback_font
	var x := at.x
	for i in s.length():
		var ch := s[i]
		var h := hash([seed_key, i, ch])
		var jitter := Vector2(((h & 0xff) / 255.0 - 0.5) * px * 0.1, (((h >> 8) & 0xff) / 255.0 - 0.5) * px * 0.15)
		draw_set_transform(Vector2(x, at.y) + jitter, (((h >> 16) & 0xff) / 255.0 - 0.5) * 0.14 - 0.04)
		draw_char(font, Vector2.ZERO, ch, px, col)
		x += font.get_char_size(ch.unicode_at(0), px).x * 0.94
	draw_set_transform(Vector2.ZERO)
	return x - at.x


## A struck-through line of handwriting: crossed out, still legible.
func strike(at: Vector2, width: float, px: int, col: Color) -> void:
	draw_line(at + Vector2(-2, -px * 0.32), at + Vector2(width + 2, -px * 0.28), col, maxf(px * 0.09, 1.5))
