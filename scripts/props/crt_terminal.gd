# scripts/props/crt_terminal.gd — JIOH-26: the green-screen terminal and its
# mail reader. Keyboard only: up and down to choose, Enter to open, Page
# Down or Space for the next page, Escape to go back and, from the list, to
# step away. Every screen takes a moment to draw, on purpose. Physical
# fidelity and the rest of the business OS belong to JIOH-9 and JIOH-75.
class_name CrtTerminal
extends Node3D

signal session_changed(active: bool)

enum Screen { LIST, READING }

const COLS := 52
const ROWS := 18
## How long a screen takes to come up.
const DRAW_SECONDS := 0.6
const GREEN := Color(0.35, 0.95, 0.45)
const DIM := Color(0.15, 0.45, 0.2)

var active := false
var screen: Screen = Screen.LIST
var inbox: Array[MailMessage] = []
var selected := 0
var page := 0
var face: PaperFace
var _drawing := 0.0


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	var beige := Color(0.78, 0.75, 0.66)
	PropMesh.box(self, "Case", Vector3(0, 0.17, 0.02), Vector3(0.38, 0.32, 0.34), beige)
	PropMesh.box(self, "Bezel", Vector3(0, 0.18, -0.152), Vector3(0.33, 0.25, 0.01), Color(0.2, 0.2, 0.19))
	PropMesh.box(self, "Keyboard", Vector3(0, 0.015, -0.30), Vector3(0.40, 0.03, 0.15), beige.darkened(0.1))
	face = PaperFace.new()
	face.size_m = Vector2(0.28, 0.21)
	face.pixels = Vector2i(560, 420)
	face.upright = true
	face.glow = true
	face.painter = _paint
	face.position = Vector3(0, 0.18, -0.158)
	face.rotation.y = PI  # the screen faces the player, along local -Z
	add_child(face)
	var it := TerminalHandle.new()
	it.terminal = self
	it.display_name = "Terminal"
	it.object_id = &"crt_terminal"
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0.17, -0.1), Vector3(0.40, 0.34, 0.3))
	WorldClock.day_rolled.connect(func(_d): load_inbox())


func restore_from_campaign() -> void:
	load_inbox()


func load_inbox() -> void:
	inbox = InformationBoard.mail_on(WorldClock.get_campaign_day())
	# Newest first, as mail readers do.
	inbox.reverse()
	inbox.sort_custom(func(a, b): return a.available_from_day > b.available_from_day)
	selected = 0
	screen = Screen.LIST
	_redraw()


func begin_session() -> void:
	active = true
	screen = Screen.LIST
	_set_locked(true)
	session_changed.emit(true)
	_redraw()


func end_session() -> void:
	active = false
	_set_locked(false)
	session_changed.emit(false)
	_redraw()


func is_drawing() -> bool:
	return _drawing > 0.0


func key(code: Key) -> void:
	if not active or is_drawing():
		return
	match screen:
		Screen.LIST:
			match code:
				KEY_UP: selected = maxi(selected - 1, 0)
				KEY_DOWN: selected = mini(selected + 1, inbox.size() - 1)
				KEY_ENTER, KEY_KP_ENTER:
					if not inbox.is_empty():
						screen = Screen.READING
						page = 0
				KEY_ESCAPE:
					end_session()
					return
				_: return
		Screen.READING:
			match code:
				KEY_PAGEDOWN, KEY_SPACE: page = mini(page + 1, _pages().size() - 1)
				KEY_PAGEUP: page = maxi(page - 1, 0)
				KEY_ESCAPE: screen = Screen.LIST
				_: return
	_redraw()


## The open message's body, wrapped and paged as the screen shows it.
func _pages() -> Array[PackedStringArray]:
	var m := inbox[selected]
	var lines := PackedStringArray()
	lines.append("FROM: " + m.sender)
	lines.append("SUBJ: " + m.subject)
	lines.append("")
	for para in InformationBoard.render_tokens(m.body).split("\n"):
		var line := ""
		for word in para.split(" "):
			if (line + " " + word).strip_edges().length() > COLS:
				lines.append(line)
				line = word
			else:
				line = (line + " " + word).strip_edges()
		lines.append(line)
	var pages: Array[PackedStringArray] = []
	for i in range(0, lines.size(), ROWS - 2):
		pages.append(lines.slice(i, i + ROWS - 2))
	return pages


func screen_text() -> String:
	if is_drawing():
		return ""
	var out := PackedStringArray()
	if screen == Screen.LIST:
		out.append("MAIL  %d MESSAGES" % inbox.size())
		for i in inbox.size():
			var m := inbox[i]
			var when := InformationBoard.describe_day(m.available_from_day)
			out.append("%s %s %-3s %-16s %s" % [">" if i == selected else " ", when.short.to_upper(),
				str(when.dom), m.sender.get_slice(" <", 0).left(16), m.subject.left(22)])
	else:
		out.append_array(_pages()[page])
		out.append("")
		out.append("PG %d/%d   PGDN MORE   ESC LIST" % [page + 1, _pages().size()])
	return "\n".join(out)


func _process(delta: float) -> void:
	if _drawing > 0.0:
		_drawing = maxf(_drawing - delta, 0.0)
		if _drawing == 0.0:
			face.refresh()


func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		key(event.keycode)


func _redraw() -> void:
	_drawing = DRAW_SECONDS if active else 0.0
	face.refresh()


func _set_locked(on: bool) -> void:
	if InteractionManager.player:
		InteractionManager.player.set_movement_locked(on)


func _paint(c: FaceCanvas) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.05, 0.03))
	if not active:
		c.text(Vector2(20, 40), "SITE OFFICE SYSTEM", 20, DIM, -1.0, HORIZONTAL_ALIGNMENT_LEFT, JiohFonts.Face.TERMINAL)
		return
	var y := 30.0
	for line in screen_text().split("\n"):
		c.text(Vector2(14, y), line, 18, GREEN, -1.0, HORIZONTAL_ALIGNMENT_LEFT, JiohFonts.Face.TERMINAL)
		y += 22.0
	if is_drawing():
		c.text(Vector2(14, 30), "PLEASE WAIT", 18, DIM, -1.0, HORIZONTAL_ALIGNMENT_LEFT, JiohFonts.Face.TERMINAL)
