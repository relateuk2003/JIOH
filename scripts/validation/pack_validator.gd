# scripts/validation/pack_validator.gd — JIOH-29: the silent validator.
#
# Pure and stateless. Called once per pack, at handout, by the handout system
# and by nothing else (tools/check_validator_refs.sh enforces it). It never
# runs while the player fills, stamps, punches or lodges; nothing in the game
# reflects a document's correctness until a trade reads it at the hatch.
class_name PackValidator
extends RefCounted

const MATRIX_PATH := "res://resources/documents/pack_matrix.tres"
const SEVERITY_PATH := "res://resources/validation/severity_table.tres"

# Loaded on first use, not preloaded: the templates, rules and failures form
# a class cycle, and a preload while that cycle is compiling binds the
# resources to a half-built script.
static var _matrix: PackMatrix
static var _severity: SeverityTable
## How many packs have been scored this session. Tests use it to prove a
## reload mid-read does not score again.
static var calls := 0


## Scores a pack for a job on its handout day. history holds earlier document
## instances, for failures inherited from previous days. Returns every
## applicable failure, not just the first.
static func score(pack: Array[DocumentInstance], job: JobRecord, day: int,
		history: Array = []) -> PackVerdict:
	calls += 1
	if _matrix == null:
		_matrix = load(MATRIX_PATH)
		_severity = load(SEVERITY_PATH)
	var verdict := PackVerdict.new()
	var ctx := {"pack": pack, "job": job, "day": day, "history": history}
	var needed: Dictionary = _matrix.documents_for(job.trade, job.job_kind)
	var wanted: Array[StringName] = []
	wanted.append_array(needed.required)
	wanted.append_array(needed.expected)

	# Absent: what should be there and is not.
	for doc_id in needed.required:
		if not _has_doc(pack, doc_id):
			verdict.failures.append(_missing(doc_id, true))
	for doc_id in needed.expected:
		if not _has_doc(pack, doc_id):
			verdict.failures.append(_missing(doc_id, false))

	var handout_date := WorldClock.date_string(ValidationRule.job_epoch_day(day))
	for doc in pack:
		var tpl := doc.template
		if not doc.doc_id() in wanted:
			verdict.failures.append(Failure.make(Failure.Code.SURPLUS_DOCUMENT, doc))
			continue
		if not tpl.trades.is_empty() and not job.trade in tpl.trades:
			verdict.failures.append(Failure.make(Failure.Code.WRONG_TRADE, doc))
		if doc.lodged_in_hole != &"" and doc.lodged_in_hole != job.trade:
			verdict.failures.append(Failure.make(Failure.Code.WRONG_PIGEON_HOLE, doc))

		# Incomplete.
		var unsigned := false
		for field in tpl.fields:
			var value: Variant = doc.get_value(field.key)
			var blank: bool = value == null or (value is String and value.strip_edges() == "") \
				or (value is Dictionary and value.is_empty()) or (value is bool and value == false)
			if not field.required or not blank:
				continue
			if field.type == DocumentField.FieldType.SIGNATURE:
				unsigned = true
				verdict.failures.append(Failure.make(Failure.Code.UNSIGNED, doc, field.key))
			else:
				verdict.failures.append(Failure.make(Failure.Code.MISSING_FIELD, doc, field.key))
		if tpl.requires_signature and not unsigned and not _any_signature(doc):
			verdict.failures.append(Failure.make(Failure.Code.UNSIGNED, doc))
		if tpl.requires_stamp:
			if doc.stamp == null:
				verdict.failures.append(Failure.make(Failure.Code.UNSTAMPED, doc))
			elif doc.stamp.stamped_date != handout_date:
				verdict.failures.append(Failure.make(Failure.Code.WRONG_DATE_ON_STAMP, doc))
		if tpl.requires_punch and not doc.punched:
			verdict.failures.append(Failure.make(Failure.Code.UNPUNCHED, doc))

		# Expired: the sheet itself is too old.
		if tpl.validity_days >= 0 and day - doc.raised_on_day > tpl.validity_days:
			verdict.failures.append(Failure.make(Failure.Code.EXPIRED, doc))

		# Wrong, contradictory, inherited: the template's authored rules.
		for rule in tpl.validation_rules:
			verdict.failures.append_array(rule.evaluate(doc, ctx))

	_dedupe(verdict)
	verdict.severity = PackVerdict.Severity.ACCEPTED
	for f in verdict.failures:
		verdict.severity = maxi(verdict.severity, _severity.severity_of(f)) as PackVerdict.Severity
	verdict.accepted = verdict.severity <= PackVerdict.Severity.GRUMBLED
	return verdict


static func _has_doc(pack: Array[DocumentInstance], doc_id: StringName) -> bool:
	return pack.any(func(d): return d.doc_id() == doc_id)


static func _missing(doc_id: StringName, blocking: bool) -> Failure:
	var f := Failure.make(Failure.Code.MISSING_DOCUMENT)
	f.doc_id = doc_id
	f.blocking = blocking
	return f


static func _any_signature(doc: DocumentInstance) -> bool:
	if doc.signature != null:
		return true
	for field in doc.template.fields:
		if field.type == DocumentField.FieldType.SIGNATURE and doc.get_value(field.key) is Dictionary \
				and not (doc.get_value(field.key) as Dictionary).is_empty():
			return true
	return false


## One failure per code, sheet and field.
static func _dedupe(verdict: PackVerdict) -> void:
	var seen := {}
	var kept: Array[Failure] = []
	for f in verdict.failures:
		var key := "%d|%s|%s|%s" % [f.code, f.instance_id, f.field_key, f.doc_id]
		if not seen.has(key):
			seen[key] = true
			kept.append(f)
	verdict.failures = kept
