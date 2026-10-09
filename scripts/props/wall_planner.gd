# scripts/props/wall_planner.gd — JIOH-26: the fortnight on the wall in
# whiteboard pen. Knows which trade is in, where, on which day; never a job
# number. Crossed-out entries stay crossed out and legible. Read by walking
# up to it and looking.
class_name WallPlanner
extends Node3D

const SIZE := Vector2(1.6, 0.8)
const MARKER := Color(0.10, 0.22, 0.55)
const MARKER_RED := Color(0.62, 0.12, 0.10)
const GRID := Color(0.55, 0.55, 0.58)

var face: PaperFace


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	PropMesh.box(self, "Frame", Vector3(0, 0, -0.012), Vector3(SIZE.x + 0.05, SIZE.y + 0.05, 0.02), Color(0.7, 0.7, 0.72))
	face = PaperFace.new()
	face.size_m = SIZE
	face.pixels = Vector2i(960, 480)
	face.upright = true
	face.painter = _paint
	add_child(face)
	WorldClock.day_rolled.connect(func(_d): face.refresh())
	CampaignState.campaign_started.connect(face.refresh)


func restore_from_campaign() -> void:
	face.refresh()


func _paint(c: FaceCanvas) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.96, 0.96, 0.95))
	if not CampaignState.has_campaign():
		return
	var cell := Vector2(s.x / 7.0, (s.y - 40) / 2.0)
	c.text(Vector2(12, 28), "WORKS PLANNER", 22, Color(0.2, 0.2, 0.2))
	var columns := {}  # campaign day -> top-left of its cell
	for i in CampaignState.CAMPAIGN_LENGTH:
		var day := i + 1
		var at := Vector2((i % 7) * cell.x, 40 + (i / 7) * cell.y)
		columns[day] = at
		var info := InformationBoard.describe_day(day)
		if not CampaignState.get_day(day).is_working_day:
			c.draw_rect(Rect2(at, cell), Color(0.88, 0.88, 0.88))
		c.draw_rect(Rect2(at, cell), GRID, false, 1.0)
		c.text(at + Vector2(6, 18), "%s %d" % [info.short.to_upper(), info.dom], 15, Color(0.25, 0.25, 0.25))
	var entries := entries()
	var filled := {}
	for subject in entries:
		var e: Dictionary = entries[subject]
		if not columns.has(e.day):
			continue
		var slot: int = filled.get(e.day, 0)
		filled[e.day] = slot + 1
		var y: float = columns[e.day].y + 44 + slot * 96
		for line in e.lines:
			var at := Vector2(columns[e.day].x + 8, y)
			var w := c.hand(at, line[0], 17, MARKER, subject)
			if line[1]:
				c.strike(at, w, 17, MARKER_RED)
			y += 21


## What is written on the planner today: subject_id -> {day, lines}, each
## line [text, crossed_out]. Exactly what gets painted.
func entries() -> Dictionary:
	var out := {}
	for f in InformationBoard.from_source(&"wall_planner"):
		var e: Dictionary = out.get(f.subject_id, {"day": 0, "lines": []})
		if f.day_value() > 0 and f.answers(&"date"):
			if f.confidence == Fact.Confidence.SUPERSEDED:
				e.lines.append([InformationBoard.describe_day(f.day_value()).short, true])
			else:
				e.day = f.day_value()
		else:
			e.lines.append([f.wording if f.wording != "" else f.value, f.confidence == Fact.Confidence.SUPERSEDED])
		out[f.subject_id] = e
	return out
