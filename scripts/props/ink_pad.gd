# scripts/props/ink_pad.gd — JIOH-27: press the stamp on it to re-ink.
class_name InkPad
extends Node3D

var receiver: InsertReceiver


func _ready() -> void:
	PropMesh.box(self, "Tin", Vector3(0, 0.008, 0), Vector3(0.11, 0.016, 0.07), Color(0.20, 0.22, 0.30))
	PropMesh.box(self, "Pad", Vector3(0, 0.0165, 0), Vector3(0.095, 0.002, 0.055), Color(0.10, 0.10, 0.16))
	receiver = PropMesh.handle(self, InkPadReceiver.new(), "Interactable", Vector3(0, 0.02, 0), Vector3(0.12, 0.05, 0.08)) as InsertReceiver
	receiver.display_name = "Ink pad"
	receiver.object_id = &"ink_pad"
