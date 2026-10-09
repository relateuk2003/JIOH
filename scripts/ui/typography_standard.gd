# scripts/ui/typography_standard.gd — JIOH-63: the authored limits documents
# are laid out against, so a page's capacity is a number, not a judgement.
# Values are in internal pixels of the page's surface texture.
class_name TypographyStandard
extends Resource

const PATH := "res://resources/fonts/typography_standard.tres"

## A held clipboard page's texture, matched to its on-screen footprint.
@export var page_pixels := Vector2i(128, 96)
@export var margin_px: int = 4
## Extra pixels between lines on top of the face's 10px line.
@export var line_gap_px: int = 1
@export var words_per_page: int = 60
## The terminal screen at reading distance.
@export var terminal_pixels := Vector2i(96, 64)


static func shipped() -> TypographyStandard:
	return load(PATH) as TypographyStandard


func lines_per_page(face: JiohFonts.Face = JiohFonts.Face.BODY) -> int:
	return (page_pixels.y - margin_px * 2) / (JiohFonts.NATIVE[face] + line_gap_px)


func fits_page(text: String) -> bool:
	return text.split(" ", false).size() <= words_per_page
