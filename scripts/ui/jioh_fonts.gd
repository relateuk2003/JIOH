# scripts/ui/jioh_fonts.gd — JIOH-63: the three faces, and the only way code
# asks for a font. Every face is a bitmap built from resources/fonts/glyphs_5x9.txt;
# sizes are whole multiples of the native size, never fractional.
class_name JiohFonts
extends RefCounted

enum Face { BODY, DISPLAY, TERMINAL }

const PATHS := [
	"res://resources/fonts/jioh_body_6px.fnt",
	"res://resources/fonts/jioh_display_10px.fnt",
	"res://resources/fonts/jioh_terminal_8px.fnt",
]
## Native line height of each face, in its own pixels.
const NATIVE := [10, 20, 10]

static var _cache: Array[Font] = [null, null, null]


static func font(face: Face) -> Font:
	if _cache[face] == null:
		_cache[face] = load(PATHS[face])
	return _cache[face]


## A font size for a whole-number scale of a face.
static func size(face: Face, scale := 1) -> int:
	return NATIVE[face] * maxi(scale, 1)


## The nearest whole scale of the body face for a line height in pixels.
static func scale_for(px: float, face: Face = Face.BODY) -> int:
	return maxi(1, roundi(px / NATIVE[face]))


static func width_of(text: String, face: Face, scale := 1) -> float:
	return font(face).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size(face, scale)).x
