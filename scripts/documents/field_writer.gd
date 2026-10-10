# scripts/documents/field_writer.gd — JIOH-71: putting biro on a form, shared
# by the desk (JIOH-23) and the clipboard, so a field behaves the same
# wherever the paper is.
#
# Typing goes into the box as it is typed. Tab and Shift+Tab move through the
# boxes in printed order, committing whatever the box holds, empty included.
# Boxes run out of room silently. Dates are three two-character boxes. A
# signature is a stroke of any shape. There is no validation, no hint, no
# clipboard and no undo: what is written is what was written.
class_name FieldWriter
extends RefCounted

## The live value changed; redraw the sheet.
signal changed
signal committed(doc: DocumentInstance, field: DocumentField, value: Variant)
signal signed(doc: DocumentInstance)

const FieldType := DocumentField.FieldType

var doc: DocumentInstance
var active_field: DocumentField = null
var buffer: String = ""
## A signature box has been touched and is waiting for (or taking) a stroke.
var signing := false
## Space or x ticks a focused tickbox. The clipboard allows it; at the desk a
## tick takes the pen.
var keyboard_ticks := false
var _stroke := PackedVector2Array()


func _init() -> void:
	# Quitting mid-word keeps the word (JIOH-82): the box is written as it
	# stands before the closing save.
	CampaignState.closing.connect(leave)


func stroke() -> PackedVector2Array:
	return _stroke


## The nib touches a box. Tickboxes toggle there and then; signature boxes
## wait for a stroke; everything else opens for typing.
func activate(f: DocumentField) -> void:
	leave()
	match f.type:
		FieldType.TICKBOX:
			_toggle(f)
		FieldType.SIGNATURE:
			active_field = f
			signing = true
		_:
			active_field = f
			buffer = _stored_text(f)


## Tab (+1) and Shift+Tab (-1) through the printed order, wrapping. Focus
## rests on tickboxes and signature boxes without touching them.
func move_focus(step: int) -> void:
	if active_field == null:
		return
	var fields := doc.template.fields
	var i := fields.find(active_field)
	leave()
	var next := fields[posmod(i + step, fields.size())]
	if next.type == FieldType.TICKBOX or next.type == FieldType.SIGNATURE:
		active_field = next
		buffer = ""
	else:
		activate(next)


## Focus on the first box printed on the sheet.
func focus_first() -> void:
	leave()
	if doc == null or doc.template.fields.is_empty():
		return
	var f: DocumentField = doc.template.fields[0]
	if f.type == FieldType.TICKBOX or f.type == FieldType.SIGNATURE:
		active_field = f
	else:
		activate(f)


func type_char(ch: String) -> void:
	if active_field == null or signing:
		return
	if active_field.type == FieldType.TICKBOX:
		if keyboard_ticks and ch in [" ", "x", "X"]:
			_toggle(active_field)
		return
	if active_field.type == FieldType.SIGNATURE:
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
	if active_field == null or signing or buffer.is_empty():
		return
	buffer = buffer.left(-1)
	_write_live()


## Leaves the active box, committing what it holds, empty included.
func leave() -> void:
	if active_field == null:
		return
	var f := active_field
	active_field = null
	signing = false
	_stroke = PackedVector2Array()
	if f.type == FieldType.TICKBOX or f.type == FieldType.SIGNATURE:
		buffer = ""
		return
	var stored := _value_of_buffer(f)
	buffer = ""
	doc.set_value(f.key, stored)
	_commit(f, stored)
	changed.emit()


## A signature stroke, in the box's own 0..1 space. Any shape is accepted.
func begin_stroke(at: Vector2) -> void:
	if signing:
		_stroke = PackedVector2Array([at])


func add_stroke_point(at: Vector2) -> void:
	if signing and not _stroke.is_empty():
		_stroke.append(at.clamp(Vector2.ZERO, Vector2.ONE))
		changed.emit()


func end_stroke() -> void:
	if not signing or _stroke.is_empty():
		return
	var f := active_field
	doc.set_value(f.key, {"by": "player", "points": _stroke})
	if doc.signature == null:
		doc.sign(&"player")
	_stroke = PackedVector2Array()
	active_field = null
	signing = false
	_commit(f, doc.get_value(f.key))
	changed.emit()
	signed.emit(doc)


## Keyboard entry for the active box. Returns true when the event was the
## writer's (every key is, while a box is open: typing never walks).
func handle_key(event: InputEvent) -> bool:
	if active_field == null or not event is InputEventKey:
		return false
	if not event.pressed:
		return true
	# No clipboard, no undo: these keys simply do nothing.
	for a in [&"ui_paste", &"ui_copy", &"ui_cut", &"ui_undo", &"ui_redo"]:
		if event.is_action_pressed(a):
			return true
	if event.is_action_pressed(&"ui_focus_prev"):
		move_focus(-1)
	elif event.is_action_pressed(&"ui_focus_next"):
		move_focus(1)
	elif event.is_action_pressed(&"ui_text_backspace", true):
		backspace()
	elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
		type_char(String.chr(event.unicode))
	return true


## Holding use draws; mouse motion moves the nib across the box.
func handle_signing_input(event: InputEvent) -> bool:
	if not signing:
		return false
	if event.is_action_pressed(&"use"):
		begin_stroke(Vector2(0.05, 0.6))
		return true
	if event.is_action_released(&"use"):
		end_stroke()
		return true
	if event is InputEventMouseMotion and not _stroke.is_empty():
		add_stroke_point(_stroke[_stroke.size() - 1] + event.relative * Vector2(0.004, 0.012))
		return true
	return false


## The value being typed, as the sheet should show it.
func live_value() -> Variant:
	if signing and not _stroke.is_empty():
		return {"points": _stroke}
	return null


func _toggle(f: DocumentField) -> void:
	doc.set_value(f.key, not bool(doc.get_value(f.key, false)))
	_commit(f, doc.get_value(f.key))
	changed.emit()


func _write_live() -> void:
	doc.set_value(active_field.key, _value_of_buffer(active_field))
	changed.emit()


func _value_of_buffer(f: DocumentField) -> String:
	if f.type != FieldType.DATE:
		return buffer
	if buffer.is_empty():
		return ""
	return "%s/%s/%s" % [buffer.substr(0, 2), buffer.substr(2, 2), buffer.substr(4, 2)]


func _stored_text(f: DocumentField) -> String:
	var v: Variant = doc.get_value(f.key)
	if v == null:
		return ""
	return str(v).replace("/", "") if f.type == FieldType.DATE else str(v)


## Every committed box goes to the campaign straight away, and counts against
## the day it was written on.
func _commit(f: DocumentField, value: Variant) -> void:
	# Read once per commit, so ambient systems can feel time passing.
	WorldClock.poll()
	CampaignState.add_document(doc)
	var today := CampaignState.today_record()
	if not today.is_empty():
		today["fields_written"] = int(today.get("fields_written", 0)) + 1
	CampaignState.commit(&"field")
	committed.emit(doc, f, value)
