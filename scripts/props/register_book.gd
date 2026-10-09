# scripts/props/register_book.gd — JIOH-26: a hardback book that is a source:
# the permit register, the key register, the RAMS file. Lies open; pick it
# up and examine it to read the pages. Every line is handwriting someone
# else put there, true or not.
class_name RegisterBook
extends Node3D

enum Layout {
	## One line per job: its values side by side ("P0418  Brennan's - tower").
	LINES,
	## One block per job, each value under the label printed on template_id.
	BLOCKS,
}

@export var source: StringName = &"permit_register"
@export var title: String = "PERMIT REGISTER"
@export var layout: Layout = Layout.LINES
@export var template_id: StringName = &""

const INK := Color(0.10, 0.12, 0.30)

var face: PaperFace


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	PropMesh.box(self, "Boards", Vector3(0, 0.006, 0), Vector3(0.44, 0.012, 0.31), Color(0.18, 0.22, 0.16))
	face = PaperFace.new()
	face.size_m = Vector2(0.42, 0.297)
	face.pixels = Vector2i(840, 594)
	face.painter = _paint
	face.position.y = 0.0125
	add_child(face)
	var it := Interactable.new()
	it.verbs = Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE
	it.tags = [&"book"]
	it.display_name = title.capitalize()
	it.object_id = StringName("book_%s" % source)
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0.02, 0), Vector3(0.44, 0.04, 0.31))
	WorldClock.day_rolled.connect(func(_d): face.refresh())


func restore_from_campaign() -> void:
	face.refresh()


func _paint(c: FaceCanvas) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.94, 0.92, 0.84))
	c.draw_line(Vector2(s.x / 2, 0), Vector2(s.x / 2, s.y), Color(0.7, 0.68, 0.6), 3.0)
	c.text(Vector2(24, 34), title, 20, Color(0.25, 0.25, 0.25))
	for y in range(60, int(s.y), 26):
		c.draw_line(Vector2(16, y), Vector2(s.x / 2 - 12, y), Color(0.75, 0.80, 0.88), 1.0)
		c.draw_line(Vector2(s.x / 2 + 12, y), Vector2(s.x - 16, y), Color(0.75, 0.80, 0.88), 1.0)
	if not CampaignState.has_campaign():
		return
	var groups := grouped()
	var at := Vector2(24, 82)
	for subject in groups:
		var facts: Array = groups[subject]
		if layout == Layout.LINES:
			var line := "  ".join(facts.map(func(f): return f.value + (("  " + f.wording) if f.wording != "" else "")))
			c.hand(at, line, 17, INK, subject)
			at.y += 26
		else:
			var tpl := DocumentRegistry.get_template(template_id)
			for f in facts:
				var field := tpl.get_field(f.key) if tpl else null
				c.text(at, (field.printed_label if field else String(f.key)) + ":", 13, Color(0.3, 0.3, 0.3))
				var v: String = InformationBoard.spoken_value(f) if f.day_value() < 0 else InformationBoard.describe_day(f.day_value()).form
				c.hand(at + Vector2(170, 0), v, 16, INK, f.fact_id)
				at.y += 26
			at.y += 26
		if at.y > s.y - 30 and at.x < s.x / 2:
			at = Vector2(s.x / 2 + 24, 82)


## Facts in the book today, grouped per job, in authored order.
func grouped() -> Dictionary:
	var out := {}
	for f in InformationBoard.from_source(source):
		if not out.has(f.subject_id):
			out[f.subject_id] = []
		out[f.subject_id].append(f)
	return out
