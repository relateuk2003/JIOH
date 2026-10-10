# tests/ValidationProbe.gd — JIOH-29 / JIOH-20: the silent validator, one
# fixture per failure code, against the shipped templates and pack matrix.
# A clean electrician pack for a day-3 job is built fresh for every case and
# broken in exactly one way.
extends Probe

const JOB_DAY := 3

var job: JobRecord
var handout_epoch := 0


func _ready() -> void:
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	set_local(WED_2026_10_07, 10, 0)
	handout_epoch = MON_2026_10_05 + JOB_DAY - 1
	job = JobRecord.new()
	job.job_number = "J4471"
	job.trade = &"electrician"
	job.location = "Level 2 Riser"
	job.scope = "Replace distribution board DB2-3"
	job.start_day = JOB_DAY
	job.end_day = JOB_DAY
	job.key_number = "K112"
	job.isolation_serial = "ISO0381"

	_test_matrix()
	_test_lines_and_severities()
	_test_clean_pack()
	_test_each_code()
	_test_worst_severity_wins()
	_test_missing_documents()
	_test_conditional_documents()
	_test_validator_does_not_touch_the_pack()
	finish()


# --- Fixtures -----------------------------------------------------------------

func _sheet(doc_id: StringName) -> DocumentInstance:
	var doc := DocumentRegistry.print_document(doc_id)
	doc.raised_on_day = JOB_DAY
	for f in doc.template.fields:
		if not f.required:
			continue
		match f.type:
			DocumentField.FieldType.DATE: doc.set_value(f.key, WorldClock.form_date(handout_epoch))
			DocumentField.FieldType.TIME: doc.set_value(f.key, "09:00")
			DocumentField.FieldType.NUMBER: doc.set_value(f.key, "1")
			DocumentField.FieldType.TICKBOX: doc.set_value(f.key, true)
			DocumentField.FieldType.SIGNATURE: doc.set_value(f.key, {"by": "player"})
			_: doc.set_value(f.key, "X")
	var known := {
		&"job_number": job.job_number, &"trade": "Electrician", &"location": job.location,
		&"key_number": job.key_number, &"isolation_serial": "ISO 0381", &"permit_number": "P221",
	}
	for k in known:
		if doc.template.get_field(k):
			doc.set_value(k, known[k])
	if doc.template.requires_stamp:
		doc.apply_stamp(&"received", WorldClock.date_string(handout_epoch))
	return doc


func _pack() -> Array[DocumentInstance]:
	var p: Array[DocumentInstance] = []
	for id in [&"job_sheet", &"permit_to_work", &"rams", &"isolation_certificate", &"access_key_docket"]:
		p.append(_sheet(id))
	# RAMS were assessed a couple of days before, as they would be.
	_find(p, &"rams").set_value(&"assessment_date", WorldClock.form_date(handout_epoch - 2))
	return p


func _find(pack: Array[DocumentInstance], doc_id: StringName) -> DocumentInstance:
	for d in pack:
		if d.doc_id() == doc_id:
			return d
	return null


func _expect(label: String, pack: Array[DocumentInstance], code: Failure.Code,
		severity: PackVerdict.Severity, history: Array = []) -> PackVerdict:
	var v := PackValidator.score(pack, job, JOB_DAY, history)
	check(v.has(code), "%s raises %s (got %s)" % [label, Failure.Code.keys()[code], v.codes()])
	check(v.severity == severity, "%s is %s (got %s)" % [label,
		PackVerdict.Severity.keys()[severity], PackVerdict.Severity.keys()[v.severity]])
	check(v.accepted == (severity <= PackVerdict.Severity.GRUMBLED), "%s accepted flag" % label)
	return v


# --- Cases --------------------------------------------------------------------

func _test_matrix() -> void:
	var matrix: PackMatrix = load("res://resources/documents/pack_matrix.tres")
	var problems := matrix.problems(DocumentRegistry.has_template)
	check(problems.is_empty(), "pack matrix is sound %s" % [problems])
	check(DocumentRegistry.all_templates().size() >= 9, "nine shipped templates registered")
	for tpl in DocumentRegistry.all_templates():
		for f in tpl.fields:
			var r := f.rect
			if r.position.x < 0 or r.position.y < 0 or r.end.x > 1.0 or r.end.y > 1.0:
				check(false, "%s.%s lies on the sheet" % [tpl.doc_id, f.key])


func _test_lines_and_severities() -> void:
	var lines: HatchLines = load("res://resources/dialogue/hatch_lines.tres")
	var table: SeverityTable = load("res://resources/validation/severity_table.tres")
	for code_name in Failure.Code.keys():
		var id := StringName("hatch_" + code_name.to_lower())
		check(lines.line_for(id) != "", "hatch line for %s" % code_name)
		if code_name != "MISSING_DOCUMENT":
			check(table.severities.has(code_name), "severity for %s" % code_name)


func _test_clean_pack() -> void:
	var v := PackValidator.score(_pack(), job, JOB_DAY)
	check(v.failures.is_empty(), "clean pack has no failures (got %s)" % [v.codes()])
	check(v.accepted and v.severity == PackVerdict.Severity.ACCEPTED, "clean pack accepted")


func _test_each_code() -> void:
	var G := PackVerdict.Severity.GRUMBLED
	var R := PackVerdict.Severity.REJECTED
	var p := _pack()

	_find(p, &"job_sheet").set_value(&"site", "  ")
	_expect("blank site", p, Failure.Code.MISSING_FIELD, G)

	p = _pack()
	_find(p, &"job_sheet").set_value(&"date", WorldClock.form_date(handout_epoch - 1))
	_expect("yesterday on the job sheet", p, Failure.Code.WRONG_DATE_IN_FIELD, R)

	p = _pack()
	_find(p, &"permit_to_work").set_value(&"valid_from_date", "31/02/26")
	_expect("impossible date", p, Failure.Code.WRONG_DATE_IN_FIELD, R)

	p = _pack()
	_find(p, &"permit_to_work").apply_stamp(&"received", WorldClock.date_string(handout_epoch - 1))
	_expect("stamp wheel left on yesterday", p, Failure.Code.WRONG_DATE_ON_STAMP, G)

	p = _pack()
	_find(p, &"job_sheet").set_value(&"trade", "Carpenter")
	_expect("wrong trade written", p, Failure.Code.WRONG_TRADE, R)

	p = _pack()
	_find(p, &"isolation_certificate").set_value(&"isolation_serial", "ISO0999")
	_expect("wrong isolation serial", p, Failure.Code.WRONG_JOB_NUMBER, R)

	p = _pack()
	_find(p, &"rams").set_value(&"sign_off", {})
	var v := _expect("RAMS not signed off", p, Failure.Code.UNSIGNED, R)
	check(v.failures.any(func(f): return f.code == Failure.Code.UNSIGNED and f.field_key == &"sign_off"),
		"UNSIGNED names the signature field")

	p = _pack()
	_find(p, &"job_sheet").stamp = null
	_expect("job sheet unstamped", p, Failure.Code.UNSTAMPED, G)

	p = _pack()
	var punched_tpl: DocumentTemplate = _find(p, &"job_sheet").template.duplicate()
	punched_tpl.requires_punch = true
	_find(p, &"job_sheet").template = punched_tpl
	_expect("unpunched sheet", p, Failure.Code.UNPUNCHED, G)
	_find(p, &"job_sheet").punched = true
	check(not PackValidator.score(p, job, JOB_DAY).has(Failure.Code.UNPUNCHED), "punched sheet passes")

	p = _pack()
	_find(p, &"permit_to_work").raised_on_day = 1
	_expect("permit raised two days ago", p, Failure.Code.EXPIRED, R)

	p = _pack()
	_find(p, &"rams").set_value(&"assessment_date", WorldClock.form_date(handout_epoch - 9))
	_expect("RAMS assessed nine days ago", p, Failure.Code.EXPIRED, R)

	# A two-day job: a permit valid only for the first day has expired.
	p = _pack()
	job.end_day = JOB_DAY + 1
	v = _expect("permit short of a two-day job", p, Failure.Code.EXPIRED, R)
	check(v.failures.any(func(f): return f.code == Failure.Code.EXPIRED and f.field_key == &"valid_to_date"),
		"EXPIRED names the valid-to date")
	job.end_day = JOB_DAY

	p = _pack()
	p.append(_sheet(&"timesheet"))
	_expect("timesheet in the pack", p, Failure.Code.SURPLUS_DOCUMENT, G)

	p = _pack()
	_find(p, &"permit_to_work").set_value(&"isolation_serial", "ISO0999")
	v = _expect("permit and certificate disagree", p, Failure.Code.CONTRADICTS_SIBLING, R)
	var cert := _find(p, &"isolation_certificate")
	check(v.failures.any(func(f): return f.code == Failure.Code.CONTRADICTS_SIBLING \
		and f.other_instance_id == cert.instance_id), "CONTRADICTS_SIBLING names the other sheet")

	p = _pack()
	var old := _sheet(&"permit_to_work")
	old.raised_on_day = 2
	old.location = CampaignState.Location.HANDED_OVER
	_expect("Tuesday's permit never closed out", p, Failure.Code.UNCLOSED_PREDECESSOR, R, [old])
	old.closed_out = true
	check(not PackValidator.score(p, job, JOB_DAY, [old]).has(Failure.Code.UNCLOSED_PREDECESSOR),
		"closed-out predecessor is fine")

	p = _pack()
	_find(p, &"job_sheet").lodge(&"carpenter")
	_expect("lodged in the chippies' hole", p, Failure.Code.WRONG_PIGEON_HOLE, R)
	p = _pack()
	_find(p, &"job_sheet").lodge(&"electrician")
	check(PackValidator.score(p, job, JOB_DAY).failures.is_empty(), "right hole is fine")


func _test_worst_severity_wins() -> void:
	var p := _pack()
	_find(p, &"job_sheet").set_value(&"site", "")
	_find(p, &"rams").set_value(&"sign_off", {})
	var v := _expect("blank site and unsigned RAMS", p, Failure.Code.MISSING_FIELD,
		PackVerdict.Severity.REJECTED)
	check(v.has(Failure.Code.UNSIGNED), "both failures reported, not just the first")


func _test_missing_documents() -> void:
	var p := _pack()
	p.erase(_find(p, &"permit_to_work"))
	var v := _expect("no permit", p, Failure.Code.MISSING_DOCUMENT, PackVerdict.Severity.WALKED_OFF)
	check(v.failures.any(func(f): return f.doc_id == &"permit_to_work" and f.blocking), "missing permit is blocking")

	p = _pack()
	p.erase(_find(p, &"access_key_docket"))
	_expect("no key docket", p, Failure.Code.MISSING_DOCUMENT, PackVerdict.Severity.GRUMBLED)


func _test_conditional_documents() -> void:
	var chippy := JobRecord.new()
	chippy.job_number = "J5002"
	chippy.trade = &"carpenter"
	chippy.start_day = JOB_DAY
	chippy.end_day = JOB_DAY
	var saved := job
	job = chippy
	var sheet := _sheet(&"job_sheet")
	sheet.set_value(&"trade", "Carpenter")
	var p: Array[DocumentInstance] = [sheet]
	var v := PackValidator.score(p, chippy, JOB_DAY)
	check(not v.failures.any(func(f): return f.doc_id == &"hot_works_permit"),
		"standard carpentry needs no hot works permit")
	chippy.job_kind = &"cutting"
	v = PackValidator.score(p, chippy, JOB_DAY)
	check(v.failures.any(func(f): return f.code == Failure.Code.MISSING_DOCUMENT \
		and f.doc_id == &"hot_works_permit" and f.blocking), "cutting needs a hot works permit")
	check(v.severity == PackVerdict.Severity.WALKED_OFF, "carpenter walks off without it")
	job = saved


func _test_validator_does_not_touch_the_pack() -> void:
	var p := _pack()
	_find(p, &"job_sheet").set_value(&"site", "")
	var before := p.map(func(d): return var_to_str(d.to_dict()))
	PackValidator.score(p, job, JOB_DAY)
	var after := p.map(func(d): return var_to_str(d.to_dict()))
	check(before == after, "scoring leaves every sheet untouched")
