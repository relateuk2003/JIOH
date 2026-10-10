# tests/InformationBoardProbe.gd — JIOH-26: the knowledge layer and its
# build-time auditor.
extends Probe


func _ready() -> void:
	use_fake_clock(MON_2026_10_05, 9, 0)
	CampaignState.new_campaign()
	set_local(WED_2026_10_07, 10, 0)  # day 3
	var matrix: PackMatrix = load("res://resources/documents/pack_matrix.tres")

	# The shipped knowledge passes.
	var a := _audit(InformationBoard.days, matrix)
	check(a.passed(), "the shipped knowledge passes the auditor %s" % [a.failures])
	check(InformationBoard.jobs_prepared_on(3).size() == 2, "day 3 prepares two packs for day 4")

	# Queries return every answer, contradictions included, never resolved.
	var dates := InformationBoard.query(&"d4_carpentry", &"date")
	var values := dates.map(func(f): return f.value)
	check(values.size() == 2 and "day:4" in values and "day:5" in values,
		"the planner and the answerphone both answer when the joiners come (%s)" % [values])
	var keys := InformationBoard.query(&"d4_carpentry", &"key_number").map(func(f): return f.value)
	check(keys == ["K14", "K41"], "register and hook both answer for the key, in authored order (%s)" % [keys])
	check(InformationBoard.query(&"d4_carpentry", &"valid_from_date").size() == 2,
		"the job's day also answers the permit's valid-from date")
	check(not InformationBoard.from_source(&"wall_planner").any(func(f): return f.answers(&"job_number")),
		"the wall planner carries no job numbers")
	check(InformationBoard.query(&"d4_scaffold", &"job_number", 2).is_empty()
		and InformationBoard.query(&"d4_scaffold", &"job_number", 3).size() == 1,
		"yesterday's returned sheet carries the scaffold job number from day 3, not before")
	check(not InformationBoard.has_method(&"truth_of") and not InformationBoard.has_method(&"resolve"),
		"the board has no way to say which source is right")

	# The auditor fails what it should.
	var broken := _copy_day3()
	broken.facts = broken.facts.filter(func(f): return f.fact_id != &"s_permit")
	a = _audit({3: broken}, matrix)
	check(not a.passed() and Array(a.failures).any(func(s): return "permit_number" in s and "d4_scaffold" in s),
		"a field with no source fails the build")

	broken = _copy_day3()
	var leak := Fact.new()
	leak.fact_id = &"leak"
	leak.subject_id = &"d4_scaffold"
	leak.key = &"job_number"
	leak.value = "J2207"
	leak.sources = [&"wall_planner"]
	broken.facts.append(leak)
	a = _audit({3: broken}, matrix)
	check(Array(a.failures).any(func(s): return "wall planner" in s), "a job number on the planner fails the build")

	broken = _copy_day3()
	(broken.facts.filter(func(f): return f.fact_id == &"c_jobno")[0] as Fact).value = "J9999"
	a = _audit({3: broken}, matrix)
	check(Array(a.failures).any(func(s): return "c_jobno" in s), "an uncontradicted fact that disagrees with the job fails")

	broken = _copy_day3()
	(broken.contradictions[0] as ContradictionPair).truth = &"nonsense"
	a = _audit({3: broken}, matrix)
	check(Array(a.failures).any(func(s): return "names no truth" in s), "a contradiction without a truth fails")

	broken = _copy_day3()
	for f in broken.facts:
		if f.fact_id == &"s_jobno":
			f.available_from_day = 4
	a = _audit({3: broken}, matrix)
	check(Array(a.failures).any(func(s): return "d4_scaffold" in s and "job_number" in s),
		"a fact that only turns up after the pack is due does not count")
	finish()


func _audit(days: Dictionary, matrix: PackMatrix) -> KnowledgeAuditor:
	return KnowledgeAuditor.run(days, matrix, DocumentRegistry.has_template, DocumentRegistry.get_template)


func _copy_day3() -> DayKnowledge:
	return (InformationBoard.days[3] as DayKnowledge).duplicate(true)
