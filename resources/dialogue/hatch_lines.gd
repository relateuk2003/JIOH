# resources/dialogue/hatch_lines.gd — JIOH-29: what a tradesperson says about
# each failure, as a person, never as an error string. Faces are blank, so the
# line and the pause carry the whole performance.
class_name HatchLines
extends Resource

## spoken_line_id -> PackedStringArray of variants.
@export var lines: Dictionary = {}


func line_for(id: StringName, variant: int = 0) -> String:
	var options: PackedStringArray = lines.get(id, PackedStringArray())
	if options.is_empty():
		return ""
	return options[posmod(variant, options.size())]
