# tools/build_roster.gd — JIOH-21: writes the ten trades, their voice sets and
# body profiles from the table below. Run as a scene so autoloads exist:
#
#   godot --headless --path . res://tools/build_roster.tscn
#
# Once a writer is tuning trades in the editor the .tres files are the source
# of truth; this table is the first draft of the cast.
#
# Read across a row and the character should be there before a line is
# spoken: the gas engineer is early, patient and will not touch a bad pack;
# the scaffolder is early, impatient and signs anything.
extends Node

const OUT := "res://resources/trades/"
const B := BodyProfileData.Build

# id, first, surname, company,
# [window start, end, variance, drift/strike, lets self in],
# patience s, tolerance, read s/page,
# [height, build, gait, kit colour, pose, kit notes],
# [pitch, wpm], lines by situation
#
# WAITING: beat mask (bit per WaitingBehaviour.LADDER rung), knock style,
# leaves a note, tries the phone, mutters. The scaffolder knocks twice and
# goes; the asbestos surveyor never knocks, she writes.
const ALL := 0xFF
const NO_KNOCKS := 0xFF & ~(1 << 3) & ~(1 << 5)
const WAITING := {
	&"electrician": [ALL, &"rap", false, true, true],
	&"carpenter": [ALL, &"knuckles", true, true, false],
	&"gas_engineer": [ALL, &"polite", true, true, false],
	&"plasterer": [ALL, &"bang", false, false, true],
	&"decorator": [ALL, &"tap", true, false, false],
	&"flooring_fitter": [ALL, &"rap", false, false, false],
	&"fire_alarm_engineer": [ALL, &"polite", true, true, false],
	&"asbestos_surveyor": [NO_KNOCKS, &"none", true, false, false],
	&"cleaner": [ALL, &"tap", true, false, true],
	&"scaffolder": [ALL, &"bang", false, false, true],
}
const CAST := [
	[&"electrician", "Lee", "Hollins", "Hollins Electrical",
		[5, 15, 4, 6, false], 150.0, 1, 6.0,
		[1.80, B.SLIGHT, 1.45, Color(0.16, 0.2, 0.32), &"fidget", "Navy work trousers, tester clipped to the belt, lanyard full of keys."],
		[1.05, 175],
		{"greeting": ["Morning. Isolation cert in there?", "Hollins. Should be a pack for me."],
		 "waiting": ["...", "Any chance of this today?"],
		 "accepted": ["Lovely. Ta.", "Right, cheers."],
		 "queried": ["Where's the isolation cert?", "This isn't signed off. I'm not touching it."],
		 "refused": ["No. Not without the cert. Not doing it.", "Ring me when it's sorted."],
		 "walked": ["I've got another job at ten. I'm off."]}],
	[&"carpenter", "Kev", "Moyes", "Moyes Joinery",
		[20, 45, 8, 5, false], 240.0, 3, 3.0,
		[1.75, B.STOCKY, 1.2, Color(0.55, 0.42, 0.28), &"lean", "Sawdust on everything. Pencil behind the ear. Rigger boots, laces never done."],
		[0.9, 140],
		{"greeting": ["Alright. Moyes, for the fire door.", "Morning, morning."],
		 "waiting": ["No rush, mate.", "Kettle on back there?"],
		 "accepted": ["Smashing.", "That'll do."],
		 "queried": ["This says Thursday, I thought it was Wednesday?", "Is that the right room, that?"],
		 "refused": ["Can't go in on that, can I. Sort it and I'll come back."],
		 "walked": ["I'll be in the van. Give us a shout."]}],
	[&"gas_engineer", "Alan", "Pryce", "Pryce Heating & Gas",
		[0, 4, 1, 2, false], 420.0, 0, 14.0,
		[1.72, B.AVERAGE, 1.1, Color(0.85, 0.85, 0.82), &"still", "Pressed polo, ID card on a reel, clipboard of his own. Reads everything."],
		[0.95, 125],
		{"greeting": ["Good morning. Pryce, Gas Safe. I'll need the full pack, please."],
		 "waiting": ["I'll wait."],
		 "accepted": ["Thank you. That's all in order."],
		 "queried": ["The isolation reference doesn't match. I can't start on that.", "There's no hot works on this."],
		 "refused": ["I'm sorry. My registration's on the line. I won't sign for this."],
		 "walked": ["I've waited as long as I can. I'll call the office."]}],
	[&"plasterer", "Wayne", "Doherty", "Doherty Plastering",
		[10, 30, 6, 8, false], 120.0, 2, 2.0,
		[1.83, B.HEAVY, 1.5, Color(0.92, 0.9, 0.86), &"fidget", "White-spattered everything. Radio under one arm. Always mid-sentence on the phone."],
		[1.0, 190],
		{"greeting": ["Doherty. Quick as you like.", "Yeah, plastering, what've you got."],
		 "waiting": ["Come on.", "Mix is going off, this."],
		 "accepted": ["Sound."],
		 "queried": ["What's this bit? Never mind, what's it say?"],
		 "refused": ["I'm not standing here all day for a bit of paper."],
		 "walked": ["Forget it. Tomorrow."]}],
	[&"decorator", "Terry", "Faulkner", "Faulkner Decorators",
		[100, 140, 25, 5, false], 360.0, 4, 4.0,
		[1.70, B.AVERAGE, 0.9, Color(0.95, 0.95, 0.95), &"lean", "Whites gone grey. Flat cap. Never in a hurry and never early."],
		[0.85, 120],
		{"greeting": ["Morning, love. Faulkner. Not late, am I?", "Hello hello."],
		 "waiting": ["Take your time.", "Lovely day for it."],
		 "accepted": ["Champion."],
		 "queried": ["Doesn't matter, I'll sort it with the site lad."],
		 "refused": ["Fair enough. I'll have a cuppa and come back."],
		 "walked": ["I'll pop back after dinner."]}],
	[&"flooring_fitter", "Shaun", "Ellery", "Ellery Floors",
		[30, 60, 10, 6, false], 180.0, 2, 5.0,
		[1.77, B.SLIGHT, 1.3, Color(0.2, 0.25, 0.2), &"still", "Knee pads on, always. Stanley knife holster. Quiet."],
		[1.1, 150],
		{"greeting": ["Ellery. Floors.", "Morning."],
		 "waiting": ["..."],
		 "accepted": ["Cheers."],
		 "queried": ["Says bonding on the sheet. Is there a hot works?"],
		 "refused": ["Can't do it on that."],
		 "walked": ["I'll go to the next site."]}],
	[&"fire_alarm_engineer", "Priya", "Nandra", "Northgate Fire & Security",
		[15, 25, 3, 3, false], 300.0, 1, 10.0,
		[1.65, B.SLIGHT, 1.35, Color(0.7, 0.12, 0.12), &"still", "Company fleece, laptop bag, test kit on a pole. Checks the date before anything else."],
		[1.15, 165],
		{"greeting": ["Hi. Nandra, Northgate. Here for the panel."],
		 "waiting": ["Is there someone else I can ask?"],
		 "accepted": ["Great, thank you."],
		 "queried": ["The permit's for yesterday. Can you reissue it?", "Which zone is this?"],
		 "refused": ["I can't isolate a panel on this. I'll have to log it."],
		 "walked": ["I'll have to rebook. It'll be next week."]}],
	[&"asbestos_surveyor", "Gillian", "Marsh", "Marsh Environmental",
		[45, 60, 5, 2, false], 480.0, 1, 16.0,
		[1.68, B.AVERAGE, 1.0, Color(0.95, 0.75, 0.1), &"still", "Disposable coveralls folded under one arm. Sample bags. Reads every line twice."],
		[0.9, 130],
		{"greeting": ["Good morning. Gillian Marsh. Survey, Block B."],
		 "waiting": ["That's quite all right."],
		 "accepted": ["Thank you. Very clear."],
		 "queried": ["The register reference isn't on this. I'll need it."],
		 "refused": ["I'm afraid I can't enter without the correct permit."],
		 "walked": ["I'll write to your manager."]}],
	[&"cleaner", "Maureen", "Healy", "Brightwell Cleaning",
		[-25, -10, 3, 0, true], 600.0, 3, 1.5,
		[1.58, B.STOCKY, 1.1, Color(0.35, 0.55, 0.75), &"fidget", "Tabard, trolley, her own key to the side door. Knows everyone. Was here before you."],
		[1.2, 185],
		{"greeting": ["Only me! Just need me key docket, love."],
		 "waiting": ["You're alright, I'll do the bins."],
		 "accepted": ["You're a star."],
		 "queried": ["Ooh, that's not my key, that."],
		 "refused": ["Well I can't get in the plant room, can I."],
		 "walked": ["I'll leave the second floor then."]}],
	[&"scaffolder", "Dave", "Brennan", "Brennan's Scaffolding",
		[0, 10, 5, 10, false], 75.0, 4, 1.0,
		[1.88, B.HEAVY, 1.6, Color(1.0, 0.55, 0.05), &"fidget", "Orange hi-vis, harness still on, gloves in his back pocket. Already looking at his watch."],
		[0.8, 200],
		{"greeting": ["Brennan. Scaffold. Pack."],
		 "waiting": ["Come on, pal.", "Lads are waiting."],
		 "accepted": ["Ta."],
		 "queried": ["Whatever. Where do I sign."],
		 "refused": ["Not standing about for this."],
		 "walked": ["We're off. Ring Dave."]}],
]


func _ready() -> void:
	var matrix := load("res://resources/documents/pack_matrix.tres") as PackMatrix
	var roster := TradeRoster.new()
	for row in CAST:
		roster.trades.append(_trade(row, matrix))
	var problems := RosterValidator.problems(roster, matrix)
	for p in problems:
		push_error("build_roster: " + p)
	if problems.is_empty():
		ResourceSaver.save(roster, TradeRoster.PATH)
		print("build_roster: wrote %d trades" % roster.trades.size())
	get_tree().quit(0 if problems.is_empty() else 1)


func _trade(row: Array, matrix: PackMatrix) -> TradespersonData:
	var id: StringName = row[0]
	var t := TradespersonData.new()
	t.trade_id = id
	t.display_name = "%s %s" % [row[1], row[2]]
	t.surname = row[2]
	t.company = row[3]
	var w: Array = row[4]
	var p := PunctualityProfile.new()
	p.window_start_minutes = w[0]
	p.window_end_minutes = w[1]
	p.variance_minutes = w[2]
	p.drift_per_campaign_day = w[3]
	p.lets_self_in = w[4]
	t.punctuality = p
	t.patience_seconds = row[5]
	t.error_tolerance = row[6]
	t.read_pace_seconds_per_page = row[7]
	var wp := WaitingProfile.new()
	var wrow: Array = WAITING[id]
	wp.beat_mask = wrow[0]
	wp.knock_style = wrow[1]
	wp.leaves_note = wrow[2]
	wp.uses_phone = wrow[3]
	wp.mutters = wrow[4]
	t.waiting = wp
	t.regular = id == &"cleaner"
	t.works_saturdays = id == &"cleaner"
	var b: Array = row[8]
	var body := BodyProfileData.new()
	body.body_id = id
	body.height_m = b[0]
	body.build = b[1]
	body.gait_speed = b[2]
	body.kit_colour = b[3]
	body.waiting_pose = b[4]
	body.kit_notes = b[5]
	ResourceSaver.save(body, OUT + "bodies/%s.tres" % id)
	t.body_profile = load(OUT + "bodies/%s.tres" % id)
	var voice := VoiceSetData.new()
	voice.voice_id = id
	voice.pitch = row[9][0]
	voice.words_per_minute = row[9][1]
	voice.lines = row[10]
	ResourceSaver.save(voice, OUT + "voices/%s.tres" % id)
	t.voice_set = load(OUT + "voices/%s.tres" % id)
	t.required_document_types.assign(matrix.documents_for(id, &"*").required)
	var path := OUT + "%s.tres" % id
	ResourceSaver.save(t, path)
	t = load(path)
	return t
