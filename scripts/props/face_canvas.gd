# scripts/props/face_canvas.gd — the Control a PaperFace draws through.
class_name FaceCanvas
extends Control

var face: PaperFace


func _draw() -> void:
	if face and face.painter.is_valid():
		face.painter.call(self)


## Helpers shared by the painters.
## Printed text: the body face at the nearest whole scale for px, or the
## display face for headings (JIOH-63). Origins land on whole pixels.
func text(at: Vector2, s: String, px: int, col: Color, width: float = -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, face := JiohFonts.Face.BODY) -> void:
	var size_px := JiohFonts.size(face, JiohFonts.scale_for(px, face))
	draw_string(JiohFonts.font(face), at.round(), s, align, width, size_px, col)


## Marker or biro writing, nudged per glyph like the handwriting on forms.
## Whole-pixel nudges only, never tilted or scaled fractionally.
func hand(at: Vector2, s: String, px: int, col: Color, seed_key: Variant = 0) -> float:
	var font := JiohFonts.font(JiohFonts.Face.BODY)
	var size_px := JiohFonts.size(JiohFonts.Face.BODY, JiohFonts.scale_for(px))
	var x := roundf(at.x)
	for i in s.length():
		var ch := s[i]
		var h := hash([seed_key, i, ch])
		var jitter := Vector2(posmod(h, 3) - 1, posmod(h >> 8, 3) - 1)
		draw_char(font, Vector2(x, roundf(at.y)) + jitter, ch, size_px, col)
		x += font.get_char_size(ch.unicode_at(0), size_px).x
	return x - at.x


## A struck-through line of handwriting: crossed out, still legible.
func strike(at: Vector2, width: float, px: int, col: Color) -> void:
	draw_line(at + Vector2(-2, -px * 0.32), at + Vector2(width + 2, -px * 0.28), col, maxf(px * 0.09, 1.5))
