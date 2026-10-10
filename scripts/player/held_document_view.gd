# scripts/player/held_document_view.gd — JIOH-71: paper in the hands.
#
# Pick up any paperwork and it is clipped to the clipboard and lifted in
# front of you, page one first (or wherever it was left open). Next and
# previous page flip the leaf over the clip in a quarter of a second. The
# write action brings the biro to the first box on the page; from there the
# FieldWriter does what it does at the desk. Examine drops the board to your
# side so you can see where you are going, and lifts it again.
#
# Reading slows you to a shuffle; writing stops you. The board never
# objects to anything: blank boxes are allowed, lowering is always allowed.
class_name HeldDocumentView
extends Node3D

signal document_raised(doc: DocumentInstance)
signal page_turned(index: int)
signal field_written(field: DocumentField, value: Variant)
signal document_lowered

enum State { EMPTY, RAISED, ASIDE, TURNING, WRITING }

const READING_SPEED := 0.5
const MOVE_SECONDS := 0.2
const HOLD_REPEAT := 0.35
## Eye-space poses for the board.
static var DOWN := Transform3D(Basis.from_euler(Vector3(-0.9, 0.0, 0.0)), Vector3(-0.08, -0.62, -0.34))
## Square on, at the distance where the page is Clipboard.HELD_PIXELS tall
## on the 320x240 screen (60 degree vertical field of view).
static var UP := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.3646))
static var UP_LARGE := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.3))
static var SIDE := Transform3D(Basis.from_euler(Vector3(-1.05, 0.35, 0.2)), Vector3(-0.2, -0.33, -0.36))

var state: State = State.EMPTY
var clipboard: Clipboard
var stack: PaperStack = null
var page := 0
var writer := FieldWriter.new()
var _hold_wait := 0.0
var _tween: Tween


func _ready() -> void:
	clipboard = preload("res://scenes/props/clipboard.tscn").instantiate()
	clipboard.transform = DOWN
	clipboard.visible = false
	add_child(clipboard)
	clipboard.turn_finished.connect(_on_turn_finished)
	writer.keyboard_ticks = true
	writer.changed.connect(_on_writer_changed)
	writer.committed.connect(func(_d, f, v): field_written.emit(f, v))
	InteractionManager.carry_changed.connect(_on_carry_changed)


func document() -> DocumentInstance:
	return stack.documents[page] if stack and page < stack.documents.size() else null


func is_up() -> bool:
	return state in [State.RAISED, State.TURNING, State.WRITING]


# --- Raise and lower ------------------------------------------------------------------

func _on_carry_changed(item: Interactable) -> void:
	var s: PaperStack = null
	if item and is_instance_valid(item) and &"paper_stack" in item.tags:
		s = item.body() as PaperStack
	if s == stack:
		return
	if stack:
		_lower()
	if s:
		_raise(s)


func _raise(s: PaperStack) -> void:
	stack = s
	s.visible = false  # it is on the clipboard now
	page = clampi(s.documents[0].open_page, 0, s.documents.size() - 1)
	_show_page()
	clipboard.visible = true
	clipboard.transform = DOWN
	_set_state(State.RAISED)
	_move_to(_up_pose())
	document_raised.emit(document())


func _lower() -> void:
	_leave_writing()
	var s := stack
	stack = null
	if is_instance_valid(s):
		s.visible = true
		if not s.documents.is_empty():
			s.documents[0].open_page = page
			CampaignState.add_document(s.documents[0])
			CampaignState.commit(&"page")
	clipboard.anim.stop()
	_set_state(State.EMPTY)
	_move_to(DOWN, func(): clipboard.visible = stack != null)
	document_lowered.emit()


## Examine: down to your side to see the way, and back up.
func toggle_aside() -> void:
	match state:
		State.RAISED:
			_set_state(State.ASIDE)
			_move_to(SIDE)
		State.ASIDE:
			_set_state(State.RAISED)
			_move_to(_up_pose())


# --- Pages -----------------------------------------------------------------------------

func next_page() -> bool:
	if state != State.RAISED or stack == null or page + 1 >= stack.documents.size():
		return false
	page += 1
	clipboard.turn_next(document())
	_after_turn()
	return true


func previous_page() -> bool:
	if state != State.RAISED or stack == null or page == 0:
		return false
	page -= 1
	clipboard.turn_previous(document(), stack.documents[page + 1])
	_after_turn()
	return true


func _after_turn() -> void:
	stack.documents[0].open_page = page
	_set_state(State.TURNING)
	page_turned.emit(page)


func _on_turn_finished() -> void:
	if state == State.TURNING:
		_show_page()
		_set_state(State.RAISED)


func _show_page() -> void:
	var beneath: DocumentInstance = stack.documents[page + 1] if page + 1 < stack.documents.size() else null
	clipboard.show_pages(document(), beneath)


# --- Writing ---------------------------------------------------------------------------

func begin_writing() -> bool:
	if state != State.RAISED or document() == null or document().template.fields.is_empty():
		return false
	writer.doc = document()
	writer.focus_first()
	_set_state(State.WRITING)
	InteractionManager.set_blocked(self, true)
	_point_pen()
	return true


func end_writing() -> void:
	if state != State.WRITING:
		return
	_leave_writing()
	_set_state(State.RAISED)


func _leave_writing() -> void:
	if state != State.WRITING:
		return
	writer.leave()
	InteractionManager.set_blocked(self, false)
	clipboard.rest_pen()


func _point_pen() -> void:
	var f := writer.active_field
	clipboard.point_pen(f.rect.get_center() if f else null)


func _on_writer_changed() -> void:
	if writer.signing:
		clipboard.refresh(writer.active_field.key, writer.live_value())
	else:
		clipboard.refresh()


# --- Input ---------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if state != State.WRITING:
		return
	var f := writer.active_field
	if writer.signing:
		if writer.handle_signing_input(event):
			get_viewport().set_input_as_handled()
			if not writer.signing:
				_refocus_after_signing(f)
		return
	if f and f.type == DocumentField.FieldType.SIGNATURE and event.is_action_pressed(&"use"):
		writer.activate(f)
		writer.handle_signing_input(event)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and (event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.is_action_pressed(&"release_mouse")):
		end_writing()
		return
	writer.handle_key(event)
	if writer.active_field == null:
		writer.active_field = f  # a tick keeps its focus
	_point_pen()


## Signed: the nib stays on the signature box until it is tabbed away from.
func _refocus_after_signing(f: DocumentField) -> void:
	writer.active_field = f
	_point_pen()


func _unhandled_input(event: InputEvent) -> void:
	if stack == null:
		return
	if event.is_action_pressed(&"examine"):
		toggle_aside()
	elif event.is_action_pressed(&"next_page"):
		next_page()
		_hold_wait = HOLD_REPEAT
	elif event.is_action_pressed(&"previous_page"):
		previous_page()
		_hold_wait = HOLD_REPEAT
	elif event.is_action_pressed(&"write_field"):
		begin_writing()


func _process(delta: float) -> void:
	if state == State.RAISED and CampaignState.settings.get("page_turn_hold", false):
		# JIOH-11: holding the button keeps turning.
		_hold_wait -= delta
		if _hold_wait <= 0.0:
			if Input.is_action_pressed(&"next_page") and next_page():
				_hold_wait = HOLD_REPEAT
			elif Input.is_action_pressed(&"previous_page") and previous_page():
				_hold_wait = HOLD_REPEAT


func _set_state(next: State) -> void:
	state = next
	var p := InteractionManager.player
	if p == null or not is_instance_valid(p):
		return
	p.speed_scale = READING_SPEED if next in [State.RAISED, State.TURNING] else 1.0
	p.set_movement_locked(next == State.WRITING)


func _up_pose() -> Transform3D:
	return UP_LARGE if CampaignState.settings.get("large_page", false) else UP


func _move_to(pose: Transform3D, done: Callable = Callable()) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(clipboard, ^"transform", pose, MOVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if done.is_valid():
		_tween.tween_callback(done)
