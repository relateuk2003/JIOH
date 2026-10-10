# scripts/props/hole_punch.gd — JIOH-27: the two-hole punch on the desk.
#
# Push a held stack through it. Up to MAX_SHEETS at once comes out punched;
# more than that and the punch crunches halfway, tearing every sheet, which
# then has to be redone. Unpunched sheets will not go on a treasury tag or
# into the lever arch file.
class_name HolePunch
extends Node3D

signal document_punched(instance_id: StringName)
## The overloaded crunch. Carries the torn sheets; no verdict, no message.
signal punch_crunched(instance_ids: Array[StringName])

const MAX_SHEETS := 6

var receiver: InsertReceiver


func _ready() -> void:
	var grey := Color(0.32, 0.33, 0.34)
	PropMesh.box(self, "Base", Vector3(0, 0.012, 0), Vector3(0.14, 0.024, 0.09), grey)
	PropMesh.box(self, "Lever", Vector3(0, 0.045, 0.005), Vector3(0.13, 0.016, 0.07), Color(0.12, 0.12, 0.13))
	receiver = PropMesh.handle(self, HolePunchReceiver.new(), "Interactable", Vector3(0, 0.03, 0), Vector3(0.15, 0.07, 0.1)) as InsertReceiver
	receiver.display_name = "Hole punch"
	receiver.object_id = &"hole_punch"
	(receiver as HolePunchReceiver).punch = self


## Punches a stack. Returns false (and tears the lot) when overloaded.
func punch_stack(stack: PaperStack) -> bool:
	var ids: Array[StringName] = []
	for doc in stack.documents:
		ids.append(doc.instance_id)
		CampaignState.add_document(doc)
	if stack.documents.size() > MAX_SHEETS:
		for doc in stack.documents:
			doc.torn = true
		CampaignState.commit(&"punch_crunched")
		punch_crunched.emit(ids)
		return false
	for doc in stack.documents:
		doc.punched = true
	CampaignState.commit(&"punched")
	for id in ids:
		document_punched.emit(id)
	return true
