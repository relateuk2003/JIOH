# scripts/props/drawing_rack.gd — JIOH-26: the drawing rack. Every sheet the
# office has is in it, current and superseded alike, in no helpful order.
# Pull one out, lay it on the desk, read the title block.
class_name DrawingRack
extends Node3D

const SHEET := Vector2(0.594, 0.42)  # A2

var sheets: Array[DrawingProp] = []


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	var wood := Color(0.45, 0.36, 0.25)
	PropMesh.box(self, "Base", Vector3(0, 0.03, 0), Vector3(0.7, 0.06, 0.4), wood)
	PropMesh.box(self, "PostL", Vector3(-0.33, 0.55, 0), Vector3(0.04, 1.1, 0.04), wood)
	PropMesh.box(self, "PostR", Vector3(0.33, 0.55, 0), Vector3(0.04, 1.1, 0.04), wood)
	PropMesh.box(self, "Rail", Vector3(0, 1.08, 0), Vector3(0.7, 0.03, 0.06), wood)
	WorldClock.day_rolled.connect(func(_d): restore_from_campaign())


## Re-hangs today's sheets in the rack.
func restore_from_campaign() -> void:
	for s in sheets:
		if is_instance_valid(s) and s.get_parent() == self:
			s.free()
	sheets.clear()
	var drawings := InformationBoard.drawings_on(WorldClock.get_campaign_day())
	for i in drawings.size():
		var p := DrawingProp.make(drawings[i])
		add_child(p)
		# Hanging from the rail, face out, a few centimetres apart.
		p.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.06 - SHEET.y / 2.0, -0.1 + i * 0.05))
		sheets.append(p)
