# scripts/props/drawing_prop.gd — JIOH-26: one drawing sheet. The revision
# letter is in the title block, legible; nothing else says whether it is
# current.
class_name DrawingProp
extends Node3D

const INK := Color(0.12, 0.14, 0.22)

var drawing: DrawingSheet
var face: PaperFace


static func make(d: DrawingSheet) -> DrawingProp:
	var p := DrawingProp.new()
	p.drawing = d
	p.name = "Drawing_%s_%s" % [d.drawing_no, d.revision]
	return p


func _ready() -> void:
	face = PaperFace.new()
	face.size_m = DrawingRack.SHEET
	face.pixels = Vector2i(840, 594)
	face.painter = _paint
	add_child(face)
	var it := Interactable.new()
	it.verbs = Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE
	it.tags = [&"drawing"]
	it.display_name = "Drawing %s" % drawing.drawing_no
	it.object_id = StringName("drawing_%s_%s" % [drawing.drawing_no, drawing.revision])
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0.005, 0), Vector3(DrawingRack.SHEET.x, 0.01, DrawingRack.SHEET.y))


func _paint(c: FaceCanvas) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.93, 0.94, 0.96))
	c.draw_rect(Rect2(Vector2(12, 12), s - Vector2(24, 24)), INK, false, 2.0)
	# The plan: labelled spaces on a grid; carried spaces get the revision cloud.
	var cloud := PackedStringArray()
	for id in drawing.fact_ids:
		var f := InformationBoard.fact(id)
		if f:
			cloud.append(f.value)
	var n := drawing.spaces.size()
	var cols := 3
	var cell := Vector2((s.x - 60) / cols, (s.y - 200) / ceilf(n / float(cols)))
	for i in n:
		var r := Rect2(Vector2(30 + (i % cols) * cell.x, 30 + (i / cols) * cell.y), cell - Vector2(10, 10))
		c.draw_rect(r, INK, false, 1.5)
		c.text(r.position + Vector2(8, r.size.y / 2), drawing.spaces[i].to_upper(), 18, INK, r.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
		if drawing.spaces[i] in cloud:
			_cloud(c, r.grow(6))
	# Title block.
	var tb := Rect2(Vector2(s.x - 360, s.y - 150), Vector2(340, 130))
	c.draw_rect(tb, INK, false, 2.0)
	c.text(tb.position + Vector2(10, 26), drawing.title.to_upper(), 14, INK, tb.size.x - 20)
	c.text(tb.position + Vector2(10, 62), "DRG No.  " + drawing.drawing_no, 18, INK)
	c.text(tb.position + Vector2(10, 110), "REV", 16, INK)
	c.text(tb.position + Vector2(60, 114), drawing.revision, 34, INK)
	c.text(tb.position + Vector2(160, 110), "SCALE 1:100 @ A1", 13, INK)


func _cloud(c: FaceCanvas, r: Rect2) -> void:
	var step := 18.0
	var col := Color(0.55, 0.12, 0.12)
	var x := r.position.x
	while x < r.end.x:
		c.draw_arc(Vector2(x + step / 2, r.position.y), step / 2, PI, TAU, 6, col, 1.5)
		c.draw_arc(Vector2(x + step / 2, r.end.y), step / 2, 0, PI, 6, col, 1.5)
		x += step
	var y := r.position.y
	while y < r.end.y:
		c.draw_arc(Vector2(r.position.x, y + step / 2), step / 2, PI / 2, PI * 1.5, 6, col, 1.5)
		c.draw_arc(Vector2(r.end.x, y + step / 2), step / 2, -PI / 2, PI / 2, 6, col, 1.5)
		y += step
