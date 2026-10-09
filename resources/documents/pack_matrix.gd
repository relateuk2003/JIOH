# resources/documents/pack_matrix.gd — JIOH-20: which documents each trade and
# job kind needs. Queried by handout and lodgement; never shown to the player
# in any form.
class_name PackMatrix
extends Resource

## The roster of trades (JIOH-3). The validator tool checks rows against it.
const TRADES: Array[StringName] = [
	&"electrician", &"carpenter", &"gas_engineer", &"plasterer", &"decorator",
	&"flooring_fitter", &"fire_alarm_engineer", &"asbestos_surveyor", &"cleaner", &"scaffolder",
]

@export var rows: Array[PackRequirement] = []


## {"required": [...], "expected": [...]} for a job. Conditional documents are
## folded into one list or the other only when their condition holds.
func documents_for(trade: StringName, job_kind: StringName) -> Dictionary:
	var required: Array[StringName] = []
	var expected: Array[StringName] = []
	var row := _row(trade, job_kind)
	if row:
		required.append_array(row.required_docs)
		expected.append_array(row.expected_docs)
		for c in row.conditional_docs:
			if job_kind in c.when_job_kind_in:
				(required if c.blocking else expected).append(c.doc_id)
	return {"required": required, "expected": expected}


func _row(trade: StringName, job_kind: StringName) -> PackRequirement:
	var fallback: PackRequirement = null
	for r in rows:
		if r.trade != trade:
			continue
		if r.job_kind == job_kind:
			return r
		if r.job_kind == &"*":
			fallback = r
	return fallback


## Authoring mistakes in the matrix, as readable lines; empty when sound.
## has_template answers whether a doc_id has a registered template.
func problems(has_template: Callable) -> PackedStringArray:
	var out := PackedStringArray()
	for trade in TRADES:
		if not rows.any(func(r): return r.trade == trade and r.job_kind == &"*"):
			out.append("no default row for trade '%s'" % trade)
	for r in rows:
		if not r.trade in TRADES:
			out.append("row for unknown trade '%s'" % r.trade)
		var ids: Array[StringName] = []
		ids.append_array(r.required_docs)
		ids.append_array(r.expected_docs)
		for c in r.conditional_docs:
			ids.append(c.doc_id)
			if c.when_job_kind_in.is_empty():
				out.append("%s: conditional %s has no job kinds" % [r.trade, c.doc_id])
		for id in ids:
			if not has_template.call(id):
				out.append("%s: no template for '%s'" % [r.trade, id])
			if ids.count(id) > 1:
				out.append("%s: '%s' listed twice" % [r.trade, id])
	return out
