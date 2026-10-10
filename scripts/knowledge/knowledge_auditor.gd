# scripts/knowledge/knowledge_auditor.gd — JIOH-26: fairness as a build-time
# guarantee.
#
# For every day's packs, every field the player has to look up (a required
# field with a source_hint) must be answered by at least one fact findable
# on or before the day the pack is prepared. Also checks that the planner
# never carries job numbers, that contradiction pairs really contradict and
# name a truth, and that the facts nobody contradicts agree with the job
# records the validator will judge by.
class_name KnowledgeAuditor
extends RefCounted

## Fact key -> JobRecord property it must agree with.
const JOB_PROPERTIES := {
	&"job_number": &"job_number", &"location": &"location", &"site": &"site",
	&"key_number": &"key_number", &"permit_number": &"permit_number", &"trade": &"trade",
}

var report := PackedStringArray()
var failures := PackedStringArray()


static func run(days: Dictionary, matrix: PackMatrix, has_template: Callable,
		get_template: Callable) -> KnowledgeAuditor:
	var a := KnowledgeAuditor.new()
	var all_facts: Array[Fact] = []
	var losers := {}
	var keys := days.keys()
	keys.sort()
	for d in keys:
		var k: DayKnowledge = days[d]
		all_facts.append_array(k.facts)
		for c in k.contradictions:
			losers[c.fact_b if c.truth == c.fact_a else c.fact_a] = true
	var by_id := {}
	for f in all_facts:
		if by_id.has(f.fact_id):
			a.failures.append("fact id %s is used twice" % f.fact_id)
		by_id[f.fact_id] = f
		a._check_fact(f)
	a._check_carriers(days, by_id)
	for d in keys:
		var k: DayKnowledge = days[d]
		for c in k.contradictions:
			a._check_pair(c, by_id, k)
		for job in k.jobs_for_tomorrow:
			a._check_job(d, job, all_facts, losers, matrix, has_template, get_template)
	return a


func passed() -> bool:
	return failures.is_empty()


func _check_fact(f: Fact) -> void:
	if f.sources.is_empty():
		failures.append("%s has no source" % f.fact_id)
	for s in f.sources:
		if not s in Fact.SOURCES:
			failures.append("%s names an unknown source '%s'" % [f.fact_id, s])
	if f.answers(&"job_number") and &"wall_planner" in f.sources:
		failures.append("%s puts a job number on the wall planner, which never carries them" % f.fact_id)


## Facts said to be on the answerphone, the terminal or a drawing must really
## be in a message, a mail or on a sheet, in words the player can find.
func _check_carriers(days: Dictionary, by_id: Dictionary) -> void:
	var carried := {&"answerphone": {}, &"terminal_mail": {}, &"site_drawings": {}}
	for k in days.values():
		for m in k.phone_messages:
			for id in m.fact_ids:
				carried[&"answerphone"][id] = m.transcript
		for m in k.mail:
			for id in m.fact_ids:
				carried[&"terminal_mail"][id] = m.subject + "\n" + m.body
		for dr in k.drawings:
			for id in dr.fact_ids:
				carried[&"site_drawings"][id] = "\n".join(dr.spaces)
	for source in carried:
		for id in carried[source]:
			if not by_id.has(id):
				failures.append("%s carries %s, which is not a fact" % [source, id])
	for f in by_id.values():
		for source in carried:
			if not source in f.sources:
				continue
			if not carried[source].has(f.fact_id):
				failures.append("%s is on the %s but nothing there carries it" % [f.fact_id, source])
				continue
			var text: String = carried[source][f.fact_id]
			var token := "{%s}" % f.value
			if source != &"answerphone" and not (f.value in text or token in text):
				failures.append("%s: '%s' does not appear on the %s" % [f.fact_id, f.value, source])


func _check_pair(c: ContradictionPair, by_id: Dictionary, k: DayKnowledge) -> void:
	var fa: Fact = by_id.get(c.fact_a)
	var fb: Fact = by_id.get(c.fact_b)
	if fa == null or fb == null:
		failures.append("day %d: contradiction names a missing fact (%s, %s)" % [k.day, c.fact_a, c.fact_b])
		return
	if fa.subject_id != fb.subject_id or not (fa.answers(fb.key) or fb.answers(fa.key)):
		failures.append("day %d: %s and %s do not answer the same question" % [k.day, c.fact_a, c.fact_b])
	if fa.value == fb.value:
		failures.append("day %d: %s and %s agree, so they are not a contradiction" % [k.day, c.fact_a, c.fact_b])
	if c.truth != c.fact_a and c.truth != c.fact_b:
		failures.append("day %d: contradiction %s/%s names no truth" % [k.day, c.fact_a, c.fact_b])


func _check_job(day: int, job: JobRecord, facts: Array[Fact], losers: Dictionary, matrix: PackMatrix,
		has_template: Callable, get_template: Callable) -> void:
	var needed: Dictionary = matrix.documents_for(job.trade, job.job_kind)
	var docs: Array = needed.required + needed.expected
	for doc_id in docs:
		if not has_template.call(doc_id):
			failures.append("day %d: %s needs %s, which has no template" % [day, job.job_id, doc_id])
			continue
		var tpl: DocumentTemplate = get_template.call(doc_id)
		for field in tpl.fields:
			if not field.required or field.source_hint == &"" \
					or field.type in [DocumentField.FieldType.SIGNATURE, DocumentField.FieldType.TICKBOX]:
				continue
			var found := facts.filter(func(f): return f.subject_id == job.job_id \
				and f.answers(field.key) and f.available_from_day <= day)
			var where := PackedStringArray()
			for f in found:
				for s in f.sources:
					if not String(s) in where:
						where.append(String(s))
			report.append("day %d  %-13s %-22s %-20s <- %s" % [day, job.job_id, doc_id, field.key,
				", ".join(where) if not where.is_empty() else "NOTHING"])
			if found.is_empty():
				failures.append("day %d: %s %s.%s has no source on or before day %d" % [day, job.job_id, doc_id, field.key, day])
	# Uncontradicted facts must say what the job record says.
	for f in facts:
		if f.subject_id != job.job_id or losers.has(f.fact_id) or f.confidence == Fact.Confidence.SUPERSEDED:
			continue
		var expected := ""
		if f.answers(&"date") or f.answers(&"valid_from_date"):
			expected = "day:%d" % job.start_day
		elif JOB_PROPERTIES.has(f.key):
			expected = str(job.get(JOB_PROPERTIES[f.key]))
		else:
			continue
		if ValidationRule.normalise(f.value) != ValidationRule.normalise(expected):
			failures.append("%s says '%s' but %s's record says '%s'" % [f.fact_id, f.value, job.job_id, expected])
