# resources/documents/rules/field_date_age_rule.gd — JIOH-20 / JIOH-29: a date
# written on the form may be at most max_age_days old at handout (a RAMS
# assessed more than seven days ago is expired, however well filled in).
class_name FieldDateAgeRule
extends ValidationRule

@export var field_key: StringName = &"assessment_date"
@export var max_age_days: int = 7


func evaluate(doc: DocumentInstance, ctx: Dictionary) -> Array[Failure]:
	var text := str(doc.get_value(field_key, ""))
	if normalise(text) == "":
		return ok()
	var written := WorldClock.epoch_day_from_form_date(text)
	if written < 0:
		return fail(Failure.Code.WRONG_DATE_IN_FIELD, doc, field_key)
	var handout := job_epoch_day(ctx.day)
	if written > handout:
		return fail(Failure.Code.WRONG_DATE_IN_FIELD, doc, field_key)
	if handout - written > max_age_days:
		return fail(Failure.Code.EXPIRED, doc, field_key)
	return ok()
