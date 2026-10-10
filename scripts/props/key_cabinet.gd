# scripts/props/key_cabinet.gd — JIOH-26: the key cabinet's hooks, each with
# a painted label and, maybe, a key with a numbered tag. What hangs where
# comes from the facts carried by the key cabinet; the register is a
# separate book and the two are allowed to disagree. Nothing here
# reconciles them.
class_name KeyCabinet
extends Node3D

const HOOKS := Vector2i(6, 4)
## Labels and tags on hooks no fact speaks for: texture, not information.
const FILLER := {
	1: ["1.01", "3"], 2: ["1.02", "7"], 3: ["PLANT", "22"], 5: ["RISER 1", "9"], 6: ["RISER 2", ""],
	8: ["1.08", "17"], 9: ["STORE", "2"], 11: ["2.01", "30"], 12: ["2.02", ""], 15: ["2.05", "33"],
	17: ["ROOF", ""], 19: ["LIFT MR", "12"], 21: ["BIN STORE", "5"], 23: ["GATE", "1"],
}

var face: PaperFace


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	PropMesh.box(self, "Carcass", Vector3(0, 0, -0.04), Vector3(0.62, 0.48, 0.08), Color(0.42, 0.44, 0.40))
	face = PaperFace.new()
	face.size_m = Vector2(0.58, 0.44)
	face.pixels = Vector2i(580, 440)
	face.upright = true
	face.painter = _paint
	face.position.z = 0.001
	add_child(face)
	var it := Interactable.new()
	it.verbs = Interactable.Verb.EXAMINE
	it.display_name = "Key cabinet"
	it.object_id = &"key_cabinet"
	PropMesh.handle(self, it, "Interactable", Vector3(0, 0, 0.01), Vector3(0.62, 0.48, 0.04))
	WorldClock.day_rolled.connect(func(_d): face.refresh())


func restore_from_campaign() -> void:
	face.refresh()


## Hook number -> [label, key tag] as the cabinet stands today.
func hooks() -> Dictionary:
	var out := {}
	for n in FILLER:
		out[n] = FILLER[n].duplicate()
	var by_subject := {}
	for f in InformationBoard.from_source(&"key_cabinet"):
		if not by_subject.has(f.subject_id):
			by_subject[f.subject_id] = {}
		by_subject[f.subject_id][f.key] = f
	for subject in by_subject:
		var facts: Dictionary = by_subject[subject]
		if not facts.has(&"cabinet_position"):
			continue
		var hook := int(String(facts[&"cabinet_position"].value).trim_prefix("H"))
		var label: String = facts[&"cabinet_position"].wording
		if label == "":
			label = String(subject)
		var tag := ""
		if facts.has(&"key_number"):
			tag = String(facts[&"key_number"].value).trim_prefix("K")
		out[hook] = [label, tag]
	return out


func _paint(c: FaceCanvas) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.80, 0.80, 0.74))
	var cell := Vector2(s.x / HOOKS.x, s.y / HOOKS.y)
	var h := hooks()
	for i in HOOKS.x * HOOKS.y:
		var n := i + 1
		var at := Vector2((i % HOOKS.x) * cell.x, (i / HOOKS.x) * cell.y)
		var entry: Array = h.get(n, ["", ""])
		c.text(at + Vector2(6, 16), "%d" % n, 12, Color(0.35, 0.35, 0.35))
		c.hand(at + Vector2(24, 18), entry[0], 14, Color(0.1, 0.1, 0.1), n)
		var hook := at + Vector2(cell.x / 2, 34)
		c.draw_circle(hook, 4, Color(0.3, 0.3, 0.3))
		if entry[1] != "":
			c.draw_line(hook, hook + Vector2(0, 18), Color(0.55, 0.5, 0.3), 2.0)
			var tag := Rect2(hook + Vector2(-16, 18), Vector2(32, 24))
			c.draw_rect(tag, Color(0.95, 0.85, 0.3))
			c.text(tag.position + Vector2(0, 18), entry[1], 15, Color(0.1, 0.1, 0.1), tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
