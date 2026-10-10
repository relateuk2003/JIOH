# scripts/props/pen.gd — JIOH-23: the biro. Hold it to write on the sheet in
# the desk slot.
class_name Pen
extends Node3D


func _ready() -> void:
	PropMesh.box(self, "Barrel", Vector3(0, 0.004, 0), Vector3(0.14, 0.008, 0.008), Color(0.85, 0.85, 0.82))
	PropMesh.box(self, "Cap", Vector3(-0.06, 0.005, 0), Vector3(0.03, 0.01, 0.01), Color(0.12, 0.18, 0.55))
	var it := Interactable.new()
	it.verbs = Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE
	it.tags = [&"pen"]
	it.display_name = "Biro"
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0.01, 0), Vector3(0.16, 0.03, 0.04))
