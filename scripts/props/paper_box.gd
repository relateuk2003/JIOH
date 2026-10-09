# scripts/props/paper_box.gd — JIOH-27: the spare box of fanfold paper, left
# somewhere the player has to find it. Loaded into the printer's empty tray.
class_name PaperBox
extends Node3D


func _ready() -> void:
	if get_node_or_null("Interactable"):
		return
	PropMesh.box(self, "Box", Vector3(0, 0.07, 0), Vector3(0.40, 0.14, 0.28), Color(0.62, 0.52, 0.36))
	PropMesh.label(self, "Print", "LISTING PAPER  11 x 9.5", Vector3(0, 0.08, 0.141), 26)
	var it := PropMesh.handle(self, Interactable.new(), "Interactable", Vector3(0, 0.07, 0), Vector3(0.42, 0.16, 0.30))
	it.verbs = Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE
	it.tags = [&"paper_box"]
	it.display_name = "Box of printer paper"
