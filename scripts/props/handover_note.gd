# scripts/props/handover_note.gd — JIOH-57: Janice's note, left on your desk.
#
# The whole of the tutorial. Four sides of biro telling you what she does
# each day, in her words; nothing about what to press. It is ordinary paper:
# picked up, it goes on the clipboard like any form. Until it is first
# picked up it is simply part of the desk as she left it. Once taken it
# belongs to the desk drawer, which is where it is found after any reload,
# on any day of the fortnight.
#
# note_read_first_time is recorded for telemetry only. Nothing reads it.
class_name HandoverNote
extends Node3D

const TEMPLATE := &"handover_note"
const TAKEN := "handover_note_taken"
const READ_FLAG := "note_read_first_time"

var stack: PaperStack


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	InteractionManager.carry_changed.connect(_on_carry_changed)


static func taken() -> bool:
	return bool(CampaignState.story_flags.get(TAKEN, false))


## The note's sheets, page order, with fixed ids so they are the same note
## every time it is laid out.
static func print_sheets() -> Array[DocumentInstance]:
	var tpl := DocumentRegistry.get_template(TEMPLATE)
	var docs: Array[DocumentInstance] = []
	for i in tpl.handwriting.page_count:
		var d := DocumentInstance.print_new(tpl)
		d.instance_id = StringName("handover_note_%d" % (i + 1))
		d.set_value(&"sheet", i)
		d.raised_on_day = 0
		d.printed_at_unix = 0
		docs.append(d)
	return docs


func restore_from_campaign() -> void:
	if stack and is_instance_valid(stack) and stack.get_parent() == self:
		stack.free()
	stack = null
	if taken():
		return
	stack = PaperStack.make(print_sheets())
	stack.name = "HandoverNote"
	add_child(stack)


func _on_carry_changed(item: Interactable) -> void:
	if taken() or item == null or not is_instance_valid(item) or not &"paper_stack" in item.tags:
		return
	var s := item.body() as PaperStack
	if s == null or s.documents.is_empty() or s.documents[0].doc_id() != TEMPLATE:
		return
	CampaignState.story_flags[TAKEN] = true
	CampaignState.story_flags[READ_FLAG] = WorldClock.now_unix()
	for d in s.documents:
		d.location = CampaignState.Location.DRAWER
		CampaignState.add_document(d)
	CampaignState.commit(&"note", true)
