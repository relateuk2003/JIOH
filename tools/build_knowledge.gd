# tools/build_knowledge.gd — JIOH-26: writes the authored day knowledge files
# from the tables below. Run as a scene so the autoloads exist:
#
#   godot --headless --path . res://tools/build_knowledge.tscn
#
# Like the templates, the .tres files become the source of truth once a
# writer is tuning them in the editor. Day 3 is the vertical slice's day
# (JIOH-80): two trades, three documents, packs prepared for day 4.
extends Node

const S := Fact.Confidence.STATED
const G := Fact.Confidence.GARBLED
const X := Fact.Confidence.SUPERSEDED

const DAY_03 := {
	"jobs": [
		{"job_id": &"d4_scaffold", "job_number": "J2207", "trade": &"scaffolder", "site": "Block B",
			"location": "East stair L2", "scope": "Extend tower scaffold to the L2 landing",
			"start_day": 4, "end_day": 4, "permit_number": "P0418"},
		{"job_id": &"d4_carpentry", "job_number": "J2211", "trade": &"carpenter", "site": "Block B",
			"location": "Room 2.04", "scope": "Rehang the fire door to 2.04 and fit a new closer",
			"start_day": 4, "end_day": 4, "permit_number": "P0419", "key_number": "K14"},
	],
	# id, subject_id, key, value, sources, confidence, also_answers, wording, from_day
	"facts": [
		[&"s_trade", &"d4_scaffold", &"trade", "Scaffolder", [&"wall_planner"], S, [], "SCAFFOLD - Brennan's", 1],
		[&"s_site", &"d4_scaffold", &"site", "Block B", [&"wall_planner", &"terminal_mail"], S, [], "Blk B", 1],
		[&"s_date", &"d4_scaffold", &"date", "day:4", [&"wall_planner"], S, [&"valid_from_date", &"valid_to_date"], "", 1],
		[&"s_jobno", &"d4_scaffold", &"job_number", "J2207", [&"returned_sheets"], S, [], "", 3],
		[&"s_desc", &"d4_scaffold", &"description", "Extend tower scaffold to the L2 landing", [&"terminal_mail"], S, [&"works_description"], "", 2],
		[&"s_loc_b", &"d4_scaffold", &"location", "East stair L2", [&"site_drawings"], S, [&"area"], "Rev B", 1],
		[&"s_loc_a", &"d4_scaffold", &"location", "North stair L2", [&"site_drawings"], X, [&"area"], "Rev A", 1],
		[&"s_permit", &"d4_scaffold", &"permit_number", "P0418", [&"permit_register"], S, [], "Brennan's  tower  Blk B", 1],
		[&"s_ra_ref", &"d4_scaffold", &"assessment_ref", "RA-112", [&"file_store"], S, [], "", 1],
		[&"s_ra_rev", &"d4_scaffold", &"revision", "C", [&"file_store"], S, [], "", 1],
		[&"s_ra_ctl", &"d4_scaffold", &"control_measures", "Tower inspected and tagged; edge protection; exclusion zone below", [&"file_store"], S, [], "", 1],
		[&"s_ra_by", &"d4_scaffold", &"assessor", "D. Brennan", [&"file_store"], S, [], "", 1],
		[&"s_ra_date", &"d4_scaffold", &"assessment_date", "day:2", [&"file_store"], S, [], "", 2],

		[&"c_trade", &"d4_carpentry", &"trade", "Carpenter", [&"wall_planner"], S, [], "JOINER - Moyes", 1],
		[&"c_site", &"d4_carpentry", &"site", "Block B", [&"wall_planner"], S, [], "Blk B", 1],
		[&"c_date", &"d4_carpentry", &"date", "day:4", [&"wall_planner"], S, [&"valid_from_date", &"valid_to_date"], "", 1],
		[&"c_date_phone", &"d4_carpentry", &"date", "day:5", [&"answerphone"], S, [&"valid_from_date", &"valid_to_date"], "", 3],
		[&"c_jobno", &"d4_carpentry", &"job_number", "J2211", [&"terminal_mail"], S, [], "", 2],
		[&"c_desc", &"d4_carpentry", &"description", "Rehang the fire door to 2.04 and fit a new closer", [&"terminal_mail"], S, [&"works_description"], "", 2],
		[&"c_loc", &"d4_carpentry", &"location", "Room 2.04", [&"site_drawings", &"terminal_mail"], S, [&"area"], "", 1],
		[&"c_permit", &"d4_carpentry", &"permit_number", "P0419", [&"permit_register"], S, [], "Moyes  fire door", 1],
		[&"c_ra_ref", &"d4_carpentry", &"assessment_ref", "RA-087", [&"file_store"], S, [], "", 1],
		[&"c_ra_rev", &"d4_carpentry", &"revision", "B", [&"file_store"], S, [], "", 1],
		[&"c_ra_ctl", &"d4_carpentry", &"control_measures", "Two-person lift; door wedged open; dust sheets down", [&"file_store"], S, [], "", 1],
		[&"c_ra_by", &"d4_carpentry", &"assessor", "K. Moyes", [&"file_store"], S, [], "", 1],
		[&"c_ra_date", &"d4_carpentry", &"assessment_date", "day:1", [&"file_store"], S, [], "", 1],
		[&"c_key_reg", &"d4_carpentry", &"key_number", "K14", [&"key_register"], S, [], "Rm 2.04", 1],
		[&"c_key_hook", &"d4_carpentry", &"key_number", "K41", [&"key_cabinet"], S, [], "tag on the 2.04 hook", 1],
		[&"c_hook", &"d4_carpentry", &"cabinet_position", "H14", [&"key_cabinet", &"key_register"], S, [], "2.04", 1],
		[&"c_issued", &"d4_carpentry", &"issued_to", "Moyes Joinery", [&"wall_planner"], S, [], "", 1],
		[&"c_issued_phone", &"d4_carpentry", &"issued_to", "Moyes Joinery", [&"answerphone"], G, [], "", 3],
	],
	"phone": [
		[&"msg_kev", 3, "Kev (Moyes Joinery)",
			"Hiya, it's Kev, from Moyes. We'll be with you {day:5} first thing for the door in two-oh-four. Any problems give us a bell. Cheers.",
			[&"c_date_phone", &"c_issued_phone"]],
	],
	"mail": [
		[&"mail_brennan", 2, "Denise <office@brennanscaffolding.co.uk>", "Tower extension, Block B",
			"Morning,\n\nConfirming we are back {day:4} to Extend tower scaffold to the L2 landing, Block B, east stair as per the drawing. Can you have the permit ready for the lads. Job ref as on our last sheet.\n\nRegards\nDenise\nBrennan Scaffolding Ltd",
			[&"s_desc", &"s_site"]],
		[&"mail_moyes", 2, "Kev Moyes <kev@moyesjoinery.co.uk>", "Fire door 2.04 - J2211",
			"Hi,\n\nGot the order through, our job is J2211. Rehang the fire door to 2.04 and fit a new closer. It's Room 2.04 on your second floor.\n\nKev",
			[&"c_jobno", &"c_desc", &"c_loc"]],
		[&"mail_janice", 1, "Janice <janice.office@site>", "Bits and bobs",
			"Love,\n\nPrinter needs a thump if it sulks. Stamp is in the top drawer, wind it before you use it, I never do. Key book is on top of the pigeon holes.\n\nJ x",
			[]],
	],
	"drawings": [
		[&"B-201", "Block B stair cores, level 2", "A", 1, ["North stair L2", "Lift core", "Plant"], [&"s_loc_a"]],
		[&"B-201", "Block B stair cores, level 2", "B", 1, ["East stair L2", "Lift core", "Plant"], [&"s_loc_b"]],
		[&"B-204", "Block B level 2 general arrangement", "C", 1, ["Room 2.01", "Room 2.02", "Room 2.04", "Room 2.05", "WC"], [&"c_loc"]],
	],
	"contradictions": [
		[&"c_date", &"c_date_phone", &"c_date", "Kev's message names day 5; the planner says day 4. The planner is right."],
		[&"s_loc_b", &"s_loc_a", &"s_loc_b", "Rev A of the stair drawing is still in the rack."],
		[&"c_key_reg", &"c_key_hook", &"c_key_reg", "The 2.04 hook holds tag 41; the register says K14."],
	],
}


func _ready() -> void:
	_write(3, DAY_03)
	get_tree().quit()


func _write(day: int, spec: Dictionary) -> void:
	var k := DayKnowledge.new()
	k.day = day
	var jobs: Array[JobRecord] = []
	for j in spec.jobs:
		var job := JobRecord.new()
		for prop in j:
			job.set(prop, j[prop])
		jobs.append(job)
	k.jobs_for_tomorrow = jobs
	var facts: Array[Fact] = []
	for row in spec.facts:
		var f := Fact.new()
		f.fact_id = row[0]
		f.subject = &"job"
		f.subject_id = row[1]
		f.key = row[2]
		f.value = row[3]
		f.sources.assign(row[4])
		f.confidence = row[5]
		f.also_answers.assign(row[6])
		f.wording = row[7]
		f.available_from_day = row[8]
		facts.append(f)
	k.facts = facts
	var pairs: Array[ContradictionPair] = []
	for row in spec.contradictions:
		var c := ContradictionPair.new()
		c.fact_a = row[0]
		c.fact_b = row[1]
		c.truth = row[2]
		c.note = row[3]
		pairs.append(c)
	k.contradictions = pairs
	var phone: Array[PhoneMessage] = []
	for row in spec.get("phone", []):
		var m := PhoneMessage.new()
		m.message_id = row[0]
		m.available_from_day = row[1]
		m.caller = row[2]
		m.transcript = row[3]
		m.fact_ids.assign(row[4])
		phone.append(m)
	k.phone_messages = phone
	var mail: Array[MailMessage] = []
	for row in spec.get("mail", []):
		var m := MailMessage.new()
		m.message_id = row[0]
		m.available_from_day = row[1]
		m.sender = row[2]
		m.subject = row[3]
		m.body = row[4]
		m.fact_ids.assign(row[5])
		mail.append(m)
	k.mail = mail
	var drawings: Array[DrawingSheet] = []
	for row in spec.get("drawings", []):
		var d := DrawingSheet.new()
		d.drawing_no = row[0]
		d.title = row[1]
		d.revision = row[2]
		d.available_from_day = row[3]
		d.spaces = PackedStringArray(row[4])
		d.fact_ids.assign(row[5])
		drawings.append(d)
	k.drawings = drawings
	var path := "res://resources/knowledge/day_%02d.tres" % day
	var err := ResourceSaver.save(k, path)
	print("%s: %d jobs, %d facts, %d contradictions (%s)" % [path, jobs.size(), facts.size(), pairs.size(), error_string(err)])
