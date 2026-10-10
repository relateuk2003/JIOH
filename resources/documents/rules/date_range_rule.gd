# resources/documents/rules/date_range_rule.gd — JIOH-29: a permit's valid
# from/to dates must cover every day of the job. A permit covering day one of
# a two-day job but not day two is EXPIRED.
class_name DateRangeRule
extends ValidationRule

@export var from_key: StringName = &"valid_from_date"
@export var to_key: StringName = &"valid_to_date"


func evaluate(doc: DocumentInstance, ctx: Dictionary) -> Array[Failure]:
	var job: JobRecord = ctx.job
	var from_text := str(doc.get_value(from_key, ""))
	var to_text := str(doc.get_value(to_key, ""))
	if normalise(from_text) == "" or normalise(to_text) == "":
		return ok()
	var from := WorldClock.epoch_day_from_form_date(from_text)
	var to := WorldClock.epoch_day_from_form_date(to_text)
	if from < 0 or to < 0:
		return fail(Failure.Code.WRONG_DATE_IN_FIELD, doc, from_key if from < 0 else to_key)
	var first := job_epoch_day(job.start_day)
	var last := job_epoch_day(maxi(job.end_day, job.start_day))
	if from > first:
		return fail(Failure.Code.WRONG_DATE_IN_FIELD, doc, from_key)
	if to < last:
		return fail(Failure.Code.EXPIRED, doc, to_key)
	return ok()
