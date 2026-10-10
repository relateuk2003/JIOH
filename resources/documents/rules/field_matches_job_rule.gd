# resources/documents/rules/field_matches_job_rule.gd — JIOH-29: a field must
# say what the job says (its number, trade, location, key, isolation serial,
# or the date it runs).
class_name FieldMatchesJobRule
extends ValidationRule

## JobRecord property to compare against: job_number, trade, location,
## key_number, isolation_serial, previous_job_number, or "date" for the job's
## first day.
@export var job_property: StringName = &"job_number"
@export var field_key: StringName = &""
@export var failure_code: Failure.Code = Failure.Code.WRONG_JOB_NUMBER


func evaluate(doc: DocumentInstance, ctx: Dictionary) -> Array[Failure]:
	var job: JobRecord = ctx.job
	var written: Variant = doc.get_value(field_key)
	if normalise(written) == "":
		return ok()  # blank is MISSING_FIELD's business
	var matched: bool
	if job_property == &"date":
		matched = WorldClock.epoch_day_from_form_date(str(written)) == job_epoch_day(job.start_day)
	else:
		var expected: String = normalise(job.get(job_property))
		if expected == "":
			return ok()
		matched = normalise(written) == expected
	return ok() if matched else fail(failure_code, doc, field_key)
