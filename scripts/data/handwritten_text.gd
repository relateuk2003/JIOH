# scripts/data/handwritten_text.gd — JIOH-57: a note written by hand.
#
# The words are authored here as plain paragraphs. layout() wraps them onto
# pages the size a held page is drawn (Clipboard.HELD_PIXELS), and render()
# draws one page of that layout in biro from the same 5x9 glyph set the
# fonts are built from, nudged and slanted a little per letter. The
# handwriting texture is baked from render() by tools/build_handover_note,
# and the accessible presentation sets the very same lines in the body face,
# so nothing is in the handwriting that is not in the text.
class_name HandwrittenText
extends Resource

const GLYPHS := "res://resources/fonts/glyphs_5x9.txt"
const PAGE := Vector2i(120, 170)
const LEFT := 7
const TOP := 9
const PITCH := 11
const BIRO := Color(0.13, 0.19, 0.52)
const BIRO_LIGHT := Color(0.3, 0.37, 0.66)

## Paragraphs separated by blank lines. Rewriting this is a design change.
@export_multiline var text: String = ""
## Baked pages, side by side, PAGE each (tools/build_handover_note).
@export var texture: Texture2D
@export var page_count: int = 0

static var _glyphs: Dictionary = {}


static func lines_per_page() -> int:
	return (PAGE.y - TOP - 4) / PITCH


## The text wrapped into lines and the lines into pages.
func layout() -> Array:
	var lines: Array[String] = []
	var width := PAGE.x - LEFT * 2
	for para in text.strip_edges().split("\n\n"):
		# Within a paragraph a line break is hers: kept as written.
		for written in para.strip_edges().split("\n"):
			var line := ""
			for word in written.split(" ", false):
				var trial := word if line == "" else line + " " + word
				if line != "" and advance_of(trial) > width:
					lines.append(line)
					line = word
				else:
					line = trial
			lines.append(line)
		lines.append("")
	while not lines.is_empty() and lines[-1] == "":
		lines.pop_back()
	var pages: Array = []
	var per := lines_per_page()
	var i := 0
	while i < lines.size():
		var page: Array[String] = []
		for j in range(i, mini(i + per, lines.size())):
			page.append(lines[j])
		# A page never starts on a blank line.
		while not page.is_empty() and page[0] == "":
			page.pop_front()
		pages.append(page)
		i += per
	return pages


## Width in pixels of a line of handwriting.
static func advance_of(s: String) -> int:
	var w := 0
	for ch in s:
		w += _glyph(ch).advance
	return w


## One page in biro, transparent where there is no ink.
func render(page_index: int) -> Image:
	var img := Image.create(PAGE.x, PAGE.y, false, Image.FORMAT_RGBA8)
	var pages := layout()
	if page_index >= pages.size():
		return img
	var lines: Array = pages[page_index]
	for li in lines.size():
		var x := LEFT
		var y0 := TOP + li * PITCH
		var line: String = lines[li]
		for ci in line.length():
			var ch := line[ci]
			var g: Dictionary = _glyph(ch)
			var h := hash([page_index, li, ci, ch])
			var dy: int = [0, 0, 1, -1, 0][posmod(h, 5)]
			for r in g.rows.size():
				var row: String = g.rows[r]
				# A forward lean: the top rows sit a pixel to the right.
				var lean := 1 if r < 3 else 0
				for c in row.length():
					if row[c] != "#":
						continue
					var px := Vector2i(x + c + lean, y0 + r + dy)
					if px.x < 0 or px.y < 0 or px.x >= PAGE.x or px.y >= PAGE.y:
						continue
					var light := posmod(hash([h, r, c]), 7) == 0
					img.set_pixelv(px, BIRO_LIGHT if light else BIRO)
			x += g.advance
	return img


## The page's lines, for the accessible presentation.
func page_lines(page_index: int) -> Array:
	var pages := layout()
	return pages[page_index] if page_index < pages.size() else []


static func _glyph(ch: String) -> Dictionary:
	if _glyphs.is_empty():
		_load_glyphs()
	return _glyphs.get(ch, _glyphs.get("?", {"rows": [], "advance": 6}))


static func _load_glyphs() -> void:
	var f := FileAccess.open(GLYPHS, FileAccess.READ)
	var cur := ""
	var width := -1
	var rows: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("//") or line.strip_edges() == "":
			continue
		if line.begins_with("= "):
			if cur != "":
				_store(cur, rows, width)
			var parts := line.substr(2).split(" ")
			cur = " " if parts[0] == "space" else parts[0]
			width = int(parts[1]) if parts.size() > 1 else -1
			rows = []
			continue
		rows.append(line.strip_edges())
	if cur != "":
		_store(cur, rows, width)


static func _store(ch: String, rows: Array[String], width: int) -> void:
	if width < 0:
		width = 0
		for row in rows:
			var last := row.rfind("#")
			width = maxi(width, last + 1)
	# Handwriting runs a touch looser than print.
	_glyphs[ch] = {"rows": rows.duplicate(), "advance": width + 1 + (1 if ch != " " else 0)}
