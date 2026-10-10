# scripts/interaction/desk_fill_controller.gd — JIOH-23: writing on a form at
# the desk, in first person.
#
# Put a stack in the paper slot and its top sheet lies in front of you. Pick
# up the pen and use it on a box to write there. Typing goes straight onto
# the paper as handwriting; Tab and Shift+Tab move through the boxes in the
# order they are printed, committing whatever the box holds, empty included.
# Boxes run out of room silently. Dates are three two-character boxes.
# Tickboxes take a click; signature boxes take a stroke of any shape.
#
# This scene has no opinions. It never consults the rules engine, renders no
# hint, changes no material or sound with what is written, and has no
# clipboard, autocomplete or undo. Do not add any. (JIOH-29 is where
# correctness lives, and only at handout.)
class_name DeskFillController
extends Node3D

signal field_committed(instance_id: StringName, field_key: StringName, value: Variant)
signal document_signed(instance_id: StringName)
signal fill_session_ended(instance_id: StringName)
signal state_changed(to: State)

enum State { IDLE, DOCUMENT_PLACED, PEN_HELD, FIELD_ACTIVE, SIGNING }

const FieldType := DocumentField.FieldType
const TARGET_THICKNESS := 0.004  # thin, so a box aimed at obliquely is the box hit

var state: State = State.IDLE
## The stack lying in the slot, and the sheet on top of it.
var stack: PaperStack = null
var sheet: SheetView = null
var writer := FieldWriter.new()
var active_field: DocumentField:
	get:
		return writer.active_field
var buffer: String:
	get:
		return writer.buffer

var slot: DeskSlot
var paper_slot: Node3D
var corner: Interactable
var _targets: Array[FieldTarget] = []


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	var surface := Node3D.new()
	surface.name = "DeskSurface"
	add_child(surface)
	paper_slot = Node3D.new()
	paper_slot.name = "PaperSlot"
	surface.add_child(paper_slot)
	# Flat and under the paper, so the boxes on the sheet are hit first.
	slot = PropMesh.handle(surface, DeskSlot.new(), "Interactable", Vector3(0, 0.0005, 0),
		Vector3(SheetView.SIZE.x + 0.04, 0.003, SheetView.SIZE.y + 0.04)) as DeskSlot
	slot.controller = self
	slot.object_id = &"desk_paper_slot"
	slot.display_name = "Desk"
	InteractionManager.carry_changed.connect(_on_carry_changed)
	writer.changed.connect(_on_writer_changed)
	writer.committed.connect(_on_writer_committed)
	writer.signed.connect(_on_writer_signed)


func document() -> DocumentInstance:
	return stack.top() if stack else null


func pen_in_hand() -> bool:
	var held := InteractionManager.carried_item
	return held != null and &"pen" in held.tags


# --- Placing and removing paper ------------------------------------------------

## Lays a stack in the slot. Its top sheet becomes the one being written on.
func place(s: PaperStack) -> void:
	stack = s
	if s.get_parent():
		s.reparent(paper_slot, false)
	else:
		paper_slot.add_child(s)
	s.transform = Transform3D.IDENTITY
	s.interactable.set_targetable(false)
	for doc in s.documents:
		doc.location = CampaignState.Location.DESK
		CampaignState.add_document(doc)
	_show_top()
	_set_state(State.PEN_HELD if pen_in_hand() else State.DOCUMENT_PLACED)


## Takes the whole stack back out of the slot (into the player's hand).
func take() -> PaperStack:
	_leave_field()
	var s := stack
	var id := document().instance_id
	_clear_sheet()
	stack = null
	s.interactable.set_targetable(true)
	_set_state(State.IDLE)
	fill_session_ended.emit(id)
	return s


## Slides the top sheet under the rest, bringing the next one up.
func turn_page() -> void:
	if stack == null or stack.documents.size() < 2:
		return
	_leave_field()
	var id := document().instance_id
	stack.turn_top_under()
	fill_session_ended.emit(id)
	_show_top()


func _show_top() -> void:
	_clear_sheet()
	var doc := document()
	writer.doc = doc
	sheet = SheetView.make(doc)
	paper_slot.add_child(sheet)
	sheet.position = Vector3(0, stack.height() + 0.001, 0)
	for f in doc.template.fields:
		var t := FieldTarget.new()
		t.controller = self
		t.field = f
		t.object_id = StringName("field_%s" % f.key)
		var centre := SheetView.local_of_uv(f.rect.get_center())
		var size := Vector3(f.rect.size.x * SheetView.SIZE.x, TARGET_THICKNESS, f.rect.size.y * SheetView.SIZE.y)
		PropMesh.handle(sheet, t, "Field_%s" % f.key, centre + Vector3(0, TARGET_THICKNESS / 2.0, 0), size)
		t.set_targetable(pen_in_hand())
		_targets.append(t)
	corner = PropMesh.handle(sheet, PageCorner.new(), "Corner",
		SheetView.local_of_uv(Vector2(0.94, 0.96)) + Vector3(0, 0.01, 0), Vector3(0.03, 0.02, 0.03))
	(corner as PageCorner).controller = self
	corner.object_id = &"desk_page_corner"
	corner.display_name = "Corner of the page"


func _clear_sheet() -> void:
	_targets.clear()
	if sheet:
		# Deferred: the corner that turned the page is still mid-interaction.
		sheet.get_parent().remove_child(sheet)
		sheet.queue_free()
		sheet = null
		corner = null


# --- Writing -----------------------------------------------------------------------

## The pen touches a box (FieldWriter does the writing).
func activate(f: DocumentField) -> void:
	if state == State.IDLE or state == State.DOCUMENT_PLACED:
		return
	writer.activate(f)
	_sync_state()


func type_char(ch: String) -> void:
	if state == State.FIELD_ACTIVE:
		writer.type_char(ch)


func backspace() -> void:
	if state == State.FIELD_ACTIVE:
		writer.backspace()


func move_focus(step: int) -> void:
	writer.move_focus(step)
	_sync_state()


func begin_stroke(at: Vector2) -> void:
	writer.begin_stroke(at)


func add_stroke_point(at: Vector2) -> void:
	writer.add_stroke_point(at)


func end_stroke() -> void:
	writer.end_stroke()


func _input(event: InputEvent) -> void:
	if state == State.SIGNING:
		if writer.handle_signing_input(event):
			get_viewport().set_input_as_handled()
		return
	if state != State.FIELD_ACTIVE or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"release_mouse"):
		_leave_field()
		_set_state(State.PEN_HELD if pen_in_hand() else State.DOCUMENT_PLACED)
	else:
		writer.handle_key(event)


func _leave_field() -> void:
	writer.leave()


func _on_writer_changed() -> void:
	if sheet == null:
		return
	if writer.signing:
		sheet.refresh(writer.active_field.key, writer.live_value())
	else:
		sheet.refresh()


func _on_writer_committed(doc: DocumentInstance, f: DocumentField, value: Variant) -> void:
	field_committed.emit(doc.instance_id, f.key, value)


func _on_writer_signed(doc: DocumentInstance) -> void:
	document_signed.emit(doc.instance_id)
	_set_state(State.PEN_HELD if pen_in_hand() else State.DOCUMENT_PLACED)


## The state that matches what the writer is doing.
func _sync_state() -> void:
	if writer.signing:
		_set_state(State.SIGNING)
	elif writer.active_field:
		_set_state(State.FIELD_ACTIVE)


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	var p := InteractionManager.player
	if p:
		p.set_movement_locked(next == State.FIELD_ACTIVE or next == State.SIGNING)
	state_changed.emit(next)


func _on_carry_changed(_item: Interactable) -> void:
	var pen := pen_in_hand()
	for t in _targets:
		t.set_targetable(pen)
	if stack == null:
		return
	if pen and state == State.DOCUMENT_PLACED:
		_set_state(State.PEN_HELD)
	elif not pen and state != State.DOCUMENT_PLACED:
		_leave_field()
		_set_state(State.DOCUMENT_PLACED)


## Paper left on the desk comes back as one pile after a reload: the desk
## does not remember how it was arranged, only what is on it.
func restore_from_campaign() -> void:
	if stack:
		_clear_sheet()
		stack.free()
		stack = null
	_set_state(State.IDLE)
	var on_desk: Array[DocumentInstance] = []
	for doc in CampaignState.document_instances.values():
		if doc.location == CampaignState.Location.DESK:
			on_desk.append(doc)
	if on_desk.is_empty():
		return
	on_desk.sort_custom(func(a, b): return a.printed_at_unix < b.printed_at_unix)
	place(PaperStack.make(on_desk))
