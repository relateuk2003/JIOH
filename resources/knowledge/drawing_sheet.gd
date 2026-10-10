# resources/knowledge/drawing_sheet.gd — JIOH-26: one sheet in the drawing
# rack. A superseded revision is just another sheet: same paper, same
# stamp, its revision letter legible in the title block like any other.
class_name DrawingSheet
extends Resource

@export var drawing_no: String = ""
@export var title: String = ""
@export var revision: String = "A"
@export var available_from_day: int = 1
## Spaces drawn on the plan, as labels; facts' values appear among them.
@export var spaces: PackedStringArray = []
@export var fact_ids: Array[StringName] = []
