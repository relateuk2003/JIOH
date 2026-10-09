# tools/build_slice_knowledge.gd — JIOH-82: day 2's knowledge, the work the
# slice's day 3 morning hands out. Day 2 is never played in the slice (it
# opens on day 3), so this is the record of what the office knew that day:
# two jobs and the facts that answered every box on their packs.
#
#   godot --headless --path . res://tools/build_slice_knowledge.tscn
extends Node

const OUT := "res://resources/knowledge/day_02.tres"
const JOBS := [
	{"job_id": &"d3_decorating", "job_number": "J2196", "trade": &"decorator", "location": "Corridor 1.10",
		"scope": "Make good and paint the corridor walls after the cable works", "site": "Block A",
		"key_number": "K09", "trade_name": "Decorator", "firm": "Hale & Sons", "cabinet": "Row 1, hook 9",
		"ref": "RA-114", "rev": "C", "assessor": "D. Hale", "controls": "Dust sheets, low-odour paint, corridor kept open one side"},
	{"job_id": &"d3_plastering", "job_number": "J2199", "trade": &"plasterer", "location": "Room 1.07",
		"scope": "Patch and skim the ceiling where the leak came through", "site": "Block A",
		"key_number": "K11", "trade_name": "Plasterer", "firm": "Coyle Plastering", "cabinet": "Row 2, hook 3",
		"ref": "RA-087", "rev": "B", "assessor": "M. Coyle", "controls": "Mobile tower, edge protection, area taped off"},
]


func _ready() -> void:
	var k := DayKnowledge.new()
	k.day = 2
	for j in JOBS:
		var job := JobRecord.new()
		job.job_id = j.job_id
		job.job_number = j.job_number
		job.trade = j.trade
		job.location = j.location
		job.scope = j.scope
		job.start_day = 3
		job.end_day = 3
		job.site = j.site
		job.key_number = j.key_number
		k.jobs_for_tomorrow.append(job)
		var id: StringName = j.job_id
		k.facts.append(_fact(id, &"trade", j.trade_name, [&"wall_planner"]))
		k.facts.append(_fact(id, &"site", j.site, [&"wall_planner"]))
		k.facts.append(_fact(id, &"date", "day:3", [&"wall_planner"], [&"valid_from_date", &"valid_to_date"]))
		k.facts.append(_fact(id, &"job_number", j.job_number, [&"terminal_mail"]))
		k.facts.append(_fact(id, &"description", j.scope, [&"terminal_mail"], [&"works_description"]))
		k.facts.append(_fact(id, &"location", j.location, [&"site_drawings"], [&"area"]))
		k.facts.append(_fact(id, &"assessment_ref", j.ref, [&"file_store"]))
		k.facts.append(_fact(id, &"revision", j.rev, [&"file_store"]))
		k.facts.append(_fact(id, &"control_measures", j.controls, [&"file_store"]))
		k.facts.append(_fact(id, &"assessor", j.assessor, [&"file_store"]))
		k.facts.append(_fact(id, &"assessment_date", "day:1", [&"file_store"]))
		k.facts.append(_fact(id, &"key_number", j.key_number, [&"key_register"]))
		k.facts.append(_fact(id, &"cabinet_position", j.cabinet, [&"key_cabinet"]))
		k.facts.append(_fact(id, &"issued_to", j.firm, [&"wall_planner"]))
		var mail := MailMessage.new()
		mail.message_id = StringName("mail_%s" % j.trade)
		mail.available_from_day = 1
		mail.sender = "%s <office@%s.co.uk>" % [j.firm, String(j.firm).to_lower().replace(" & ", "").replace(" ", "")]
		mail.subject = "%s, %s" % [j.location, j.site]
		mail.body = "Hi,\n\nBooked in {day:3}, %s. Job: %s. Our ref is %s.\n\nThanks" % [
			j.location, j.scope, j.job_number]
		mail.fact_ids = [StringName("%s_job_number" % id), StringName("%s_description" % id)]
		k.mail.append(mail)
		var drawing := DrawingSheet.new()
		drawing.drawing_no = "A-1%02d" % k.drawings.size()
		drawing.title = "Block A level 1 general arrangement"
		drawing.spaces = PackedStringArray([j.location])
		drawing.fact_ids = [StringName("%s_location" % id)]
		k.drawings.append(drawing)
	ResourceSaver.save(k, OUT)
	print("wrote %s: %d jobs, %d facts" % [OUT, k.jobs_for_tomorrow.size(), k.facts.size()])
	get_tree().quit()


func _fact(subject: StringName, key: StringName, value: String, sources: Array, also: Array = []) -> Fact:
	var f := Fact.new()
	f.fact_id = StringName("%s_%s" % [subject, key])
	f.subject_id = subject
	f.key = key
	f.value = value
	f.available_from_day = 1
	var s: Array[StringName] = []
	s.assign(sources)
	f.sources = s
	var a: Array[StringName] = []
	a.assign(also)
	f.also_answers = a
	return f
