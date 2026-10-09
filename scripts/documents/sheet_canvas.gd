# scripts/documents/sheet_canvas.gd — JIOH-23: draws one sheet of paper into
# its SubViewport: the printed form, what has been written on it, and any
# stamp or punch holes. It draws what is there and nothing else: no field
# state, no focus ring, nothing that differs between a right entry and a
# wrong one.
class_name SheetCanvas
extends Control

const PAPER := Color(0.95, 0.94, 0.89)
const PRINT := Color(0.16, 0.16, 0.16)
const BIRO := Color(0.13, 0.19, 0.52)
const STAMP_INK := Color(0.42, 0.16, 0.42)

var doc: DocumentInstance
## The partly typed value of the field being written, drawn in place of the
## stored one until it is committed.
var live_key: StringName = &""
var live_value: Variant = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if doc == null:
		return
	var tpl := doc.template
	var font := JiohFonts.font(JiohFonts.Face.BODY)
	var ink := clampf(doc.print_quality, 0.0, 1.0)
	var print_col := Color(PRINT, ink)
	var display := JiohFonts.font(JiohFonts.Face.DISPLAY)
	draw_string(display, _at(size.x * 0.06, size.y * 0.07), tpl.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, JiohFonts.size(JiohFonts.Face.DISPLAY, JiohFonts.scale_for(size.y * 0.032, JiohFonts.Face.DISPLAY)), print_col)
	draw_string(font, _at(size.x * 0.06, size.y * 0.11), tpl.form_code,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(size.y * 0.02), print_col)
	draw_line(Vector2(size.x * 0.05, size.y * 0.135), Vector2(size.x * 0.95, size.y * 0.135), print_col, 2.0)
	var prev_y := -1.0
	for f in tpl.fields:
		var r := Rect2(f.rect.position * size, f.rect.size * size)
		var shares_row := is_equal_approx(f.rect.position.y, prev_y)
		prev_y = f.rect.position.y
		var label_size := int(clampf(size.y * 0.018, 8, 18))
		if shares_row and f.type != DocumentField.FieldType.TICKBOX:
			# A time beside its date: the label is printed small above the box.
			draw_string(font, _at(r.position.x, r.position.y - 2), f.printed_label.get_slice("(", 1).trim_suffix(")"),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x, _fs(label_size * 0.75), print_col)
		elif f.type == DocumentField.FieldType.TICKBOX:
			# Tickboxes share a line; each label sits to the right of its box.
			draw_string(font, _at(r.end.x + 3, r.position.y + r.size.y * 0.8), f.printed_label,
				HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.13 - r.size.x - 4, _fs(label_size * 0.8), print_col)
		else:
			draw_string(font, _at(size.x * 0.06, r.position.y + minf(r.size.y, size.y * 0.04) * 0.75),
				f.printed_label, HORIZONTAL_ALIGNMENT_LEFT, r.position.x - size.x * 0.08, _fs(label_size), print_col)
		if f.type == DocumentField.FieldType.DATE:
			for i in 3:
				var w := r.size.x / 3.0
				draw_rect(Rect2(r.position + Vector2(w * i, 0), Vector2(w - 2, r.size.y)), print_col, false, 1.0)
		else:
			draw_rect(r, print_col, false, 1.0)
		var value: Variant = live_value if f.key == live_key else doc.get_value(f.key)
		_draw_value(f, r, value, font)
	if doc.stamp:
		_draw_stamp(font)
	if doc.punched or doc.torn:
		for y in [0.38, 0.62]:
			var c := Vector2(size.x * 0.035, size.y * y)
			draw_circle(c, size.x * 0.012, Color(0.25, 0.22, 0.18))
	if doc.torn:
		draw_line(Vector2(0, size.y * 0.45), Vector2(size.x * 0.09, size.y * 0.52), Color(0.4, 0.38, 0.33), 3.0)


func _draw_value(f: DocumentField, r: Rect2, value: Variant, font: Font) -> void:
	match f.type:
		DocumentField.FieldType.TICKBOX:
			if value == true:
				draw_line(r.position + r.size * 0.15, r.end - r.size * 0.15, BIRO, 2.5)
				draw_line(Vector2(r.end.x - r.size.x * 0.15, r.position.y + r.size.y * 0.15),
					Vector2(r.position.x + r.size.x * 0.15, r.end.y - r.size.y * 0.15), BIRO, 2.5)
		DocumentField.FieldType.SIGNATURE:
			if value is Dictionary and value.has("points"):
				var pts: PackedVector2Array = value.points
				for i in range(1, pts.size()):
					draw_line(r.position + pts[i - 1] * r.size, r.position + pts[i] * r.size, BIRO, 2.0)
		DocumentField.FieldType.DATE:
			var parts := str(value if value != null else "").split("/")
			for i in mini(parts.size(), 3):
				var w := r.size.x / 3.0
				_hand(parts[i], Rect2(r.position + Vector2(w * i, 0), Vector2(w, r.size.y)), font, f.key)
		_:
			_hand(str(value if value != null else ""), r, font, f.key)


## Biro handwriting: one glyph at a time, each nudged and tilted a little,
## the same hand for letters and digits. Deterministic per character so a
## redraw never makes the writing crawl.
func _hand(text: String, r: Rect2, font: Font, seed_key: StringName) -> void:
	if text == "":
		return
	var px := _fs(clampf(minf(r.size.y, size.y * 0.045) * 0.62, 9, 26))
	var lines := 1 if r.size.y < px * 2.6 else int(r.size.y / (px * 1.25))
	var x := r.position.x + px * 0.3
	var line := 0
	for i in text.length():
		var ch := text[i]
		var adv := font.get_char_size(ch.unicode_at(0), px).x
		if x + adv > r.end.x - 2:
			if line + 1 >= lines:
				break
			line += 1
			x = r.position.x + px * 0.3
		var h := hash([seed_key, i, ch])
		# Whole-pixel nudges only: no tilt, no fractional placement (JIOH-63).
		var jitter := Vector2i(posmod(h, 3) - 1, posmod(h >> 8, 3) - 1)
		var base := Vector2i(roundi(x), roundi(r.position.y + px * 1.05 + line * px * 1.25)) + jitter
		draw_char(font, Vector2(base), ch, px, BIRO)
		x += adv


func _draw_stamp(font: Font) -> void:
	var s := doc.stamp
	var c := s.position * size
	var col := Color(STAMP_INK, clampf(s.ink_alpha, 0.0, 1.0))
	draw_set_transform(c, deg_to_rad(s.rotation_degrees))
	var box := Rect2(Vector2(-size.x * 0.12, -size.y * 0.035), Vector2(size.x * 0.24, size.y * 0.07))
	draw_rect(box, col, false, 2.0)
	draw_string(font, _at(box.position.x + 4, box.position.y + box.size.y * 0.38), "RECEIVED",
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 8, _fs(size.y * 0.018), col)
	var d := s.stamped_date.split("-")
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var text := s.stamped_date
	if d.size() == 3 and int(d[1]) >= 1 and int(d[1]) <= 12:
		text = "%s %s %s" % [d[2], months[int(d[1]) - 1], d[0].substr(2)]
	draw_string(font, _at(box.position.x + 4, box.position.y + box.size.y * 0.85), text,
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 8, _fs(size.y * 0.024), col)
	draw_set_transform(Vector2.ZERO)


## A body-face size at the nearest whole scale for a line height in pixels.
func _fs(px: float) -> int:
	return JiohFonts.size(JiohFonts.Face.BODY, JiohFonts.scale_for(px))


## Text origins land on whole pixels.
func _at(x: float, y: float) -> Vector2:
	return Vector2(roundi(x), roundi(y))
