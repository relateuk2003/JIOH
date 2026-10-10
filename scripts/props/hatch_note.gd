# scripts/props/hatch_note.gd — JIOH-37: what a trade leaves on the counter
# when nobody came. Torn-off notepad paper in their hand: who, when they came,
# when they gave up and what for. It stays until the player picks it up.
class_name HatchNote
extends Node3D

const SIZE := Vector2(0.105, 0.075)

var note: Dictionary = {}
var face: PaperFace


static func make(data: Dictionary) -> HatchNote:
	var n := HatchNote.new()
	n.name = "HatchNote_%s" % data.get("trade_id", "")
	n.note = data
	return n


func _ready() -> void:
	face = PaperFace.new()
	face.size_m = SIZE
	face.pixels = Vector2i(315, 225)
	face.painter = _paint
	face.position = Vector3(0, 0.0006, 0)
	add_child(face)
	var it := HatchNoteHandle.new()
	it.note_id = String(note.get("id", ""))
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0.004, 0), Vector3(SIZE.x, 0.01, SIZE.y))


## The words on it, as the trade would write them.
func text() -> PackedStringArray:
	var trade := TradeRoster.shipped().get_trade(StringName(note.get("trade_id", "")))
	var who := trade.display_name.split(" ")[0] if trade else "?"
	return PackedStringArray([
		"Came %s for %s." % [_hhmm(int(note.get("arrived_unix", 0))), note.get("came_for", "")],
		"Nobody about.",
		"Went %s." % _hhmm(int(note.get("left_unix", 0))),
		"- %s (%s)" % [who, trade.company if trade else ""],
	])


func _paint(c: FaceCanvas) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.96, 0.94, 0.82))
	for i in 6:
		c.draw_line(Vector2(0, 40 + i * 34), Vector2(c.size.x, 40 + i * 34), Color(0.6, 0.72, 0.85), 1.0)
	var y := 32.0
	var key := String(note.get("id", ""))
	for line in text():
		c.hand(Vector2(12, y), line, 22, Color(0.12, 0.14, 0.4), key + line)
		y += 34.0


func _hhmm(unix: int) -> String:
	var d := WorldClock.datetime_local(unix)
	return "%d:%02d" % [d.hour, d.minute]
