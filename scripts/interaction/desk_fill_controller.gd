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
var active_field: DocumentField = null
var buffer: String = ""

var slot: DeskSlot
var paper_slot: Node3D
var corner: Interactable
var _targets: Array[FieldTarget] = []
var _stroke := PackedVector2Array()


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

## The pen touches a box. Tickboxes toggle there and then; signature boxes
## wait for a stroke; everything else opens for typing.
func activate(f: DocumentField) -> void:
	if state == State.IDLE or state == State.DOCUMENT_PLACED:
		return
	_leave_field()
	match f.type:
		FieldType.TICKBOX:
			var doc := document()
			doc.set_value(f.key, not bool(doc.get_value(f.key, false)))
			_commit(f, doc.get_value(f.key))
			sheet.refresh()
		FieldType.SIGNATURE:
			active_field = f
			_set_state(State.SIGNING)
		_:
			active_field = f
			buffer = _stored_text(f)
			_set_state(State.FIELD_ACTIVE)


## One printable character from the keyboard.
func type_char(ch: String) -> void:
	if state != State.FIELD_ACTIVE or active_field == null:
		return
	if active_field.type == FieldType.DATE:
		if buffer.length() >= 6:
			return
		buffer += ch
		_write_live()
		if buffer.length() == 6:
			move_focus(1)  # the third box filled: on to the next field
		return
	if active_field.max_length > 0 and buffer.length() >= active_field.max_length:
		return  # the box has run out of room
	buffer += ch
	_write_live()


func backspace() -> void:
	if state != State.FIELD_ACTIVE or buffer.is_empty():
		return
	buffer = buffer.left(-1)
	_write_live()


## Tab (+1) and Shift+Tab (-1) through the printed order, wrapping.
func move_focus(step: int) -> void:
	if active_field == null:
		return
	var fields := document().template.fields
	var i := fields.find(active_field)
	_leave_field()
	var next := fields[posmod(i + step, fields.size())]
	if next.type == FieldType.TICKBOX or next.type == FieldType.SIGNATURE:
		# Focus rests there; ticking and signing still need the pen.
		active_field = next
		buffer = ""
		_set_state(State.FIELD_ACTIVE)
	else:
		activate(next)


## A signature stroke, in the box's own 0..1 space. Any shape is accepted.
func begin_stroke(at: Vector2) -> void:
	if state == State.SIGNING:
		_stroke = PackedVector2Array([at])


func add_stroke_point(at: Vector2) -> void:
	if state == State.SIGNING and not _stroke.is_empty():
		_stroke.append(at.clamp(Vector2.ZERO, Vector2.ONE))
		sheet.refresh(active_field.key, {"points": _stroke})


func end_stroke() -> void:
	if state != State.SIGNING or _stroke.is_empty():
		return
	var doc := document()
	var f := active_field
	doc.set_value(f.key, {"by": "player", "points": _stroke})
	if doc.signature == null:
		doc.sign(&"player")
	_stroke = PackedVector2Array()
	active_field = null
	_commit(f, doc.get_value(f.key))
	sheet.refresh()
	document_signed.emit(doc.instance_id)
	_set_state(State.PEN_HELD if pen_in_hand() else State.DOCUMENT_PLACED)


func _input(event: InputEvent) -> void:
	if state == State.SIGNING:
		_signing_input(event)
		return
	if state != State.FIELD_ACTIVE or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	# No clipboard, no undo: these keys simply do nothing.
	for a in [&"ui_paste", &"ui_copy", &"ui_cut", &"ui_undo", &"ui_redo"]:
		if event.is_action_pressed(a):
			return
	if event.is_action_pressed(&"ui_focus_prev"):
		move_focus(-1)
	elif event.is_action_pressed(&"ui_focus_next"):
		move_focus(1)
	elif event.is_action_pressed(&"ui_text_backspace", true):
		backspace()
	elif event.is_action_pressed(&"release_mouse"):
		_leave_field()
		_set_state(State.PEN_HELD if pen_in_hand() else State.DOCUMENT_PLACED)
	elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed \
			and active_field.type not in [FieldType.TICKBOX, FieldType.SIGNATURE]:
		type_char(String.chr(event.unicode))


# Holding the use button draws; mouse motion moves the nib across the box.
func _signing_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use"):
		begin_stroke(Vector2(0.05, 0.6))
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"use"):
		end_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _stroke.is_empty():
		var last := _stroke[_stroke.size() - 1]
		add_stroke_point(last + event.relative * Vector2(0.004, 0.012))
		get_viewport().set_input_as_handled()


func _write_live() -> void:
	document().set_value(active_field.key, _value_of_buffer())
	sheet.refresh()


func _value_of_buffer() -> String:
	if active_field.type != FieldType.DATE:
		return buffer
	if buffer.is_empty():
		return ""
	return "%s/%s/%s" % [buffer.substr(0, 2), buffer.substr(2, 2), buffer.substr(4, 2)]


func _stored_text(f: DocumentField) -> String:
	var v: Variant = document().get_value(f.key)
	if v == null:
		return ""
	return str(v).replace("/", "") if f.type == FieldType.DATE else str(v)


## Leaves the active box, committing what it holds, empty included.
func _leave_field() -> void:
	if active_field == null:
		return
	var f := active_field
	if f.type == FieldType.TICKBOX or f.type == FieldType.SIGNATURE:
		active_field = null
		buffer = ""
		return
	var stored := _value_of_buffer()
	active_field = null
	buffer = ""
	document().set_value(f.key, stored)
	_commit(f, stored)
	sheet.refresh()


func _commit(f: DocumentField, value: Variant) -> void:
	var doc := document()
	# Read once per commit, so ambient systems can feel time passing.
	WorldClock.poll()
	CampaignState.add_document(doc)
	CampaignState.commit(&"field")
	field_committed.emit(doc.instance_id, f.key, value)


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
		_stroke = PackedVector2Array()
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
