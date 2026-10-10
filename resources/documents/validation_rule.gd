# resources/documents/validation_rule.gd — JIOH-18 / JIOH-29: a check a
# template carries, run only by PackValidator at handout. Subclasses under
# resources/documents/rules/ cover field-against-job checks, cross-document
# pairs, date ranges and the history of earlier days.
class_name ValidationRule
extends Resource

## The failure taxonomy from the paperwork design doc.
enum Category { ABSENT, INCOMPLETE, EXPIRED, CONTRADICTORY, INHERITED }

@export var rule_id: StringName = &""
@export var category: Category = Category.INCOMPLETE


## Returns the failures this rule finds on doc. ctx holds "pack"
## (Array[DocumentInstance]), "job" (JobRecord), "day" (int handout day) and
## "history" (earlier DocumentInstances).
func evaluate(_doc: DocumentInstance, _ctx: Dictionary) -> Array[Failure]:
	return []


## Values are compared as players write them: case and spacing ignored.
static func normalise(v: Variant) -> String:
	return str(v if v != null else "").strip_edges().to_upper().replace(" ", "")


## The job's start day as dd/mm/yy relative to the campaign.
static func job_epoch_day(job_day: int) -> int:
	return CampaignState.campaign_start_epoch_day + job_day - 1


## A typed one-failure result (bare array literals are untyped at runtime).
static func fail(c: Failure.Code, doc: DocumentInstance, field: StringName = &"") -> Array[Failure]:
	var out: Array[Failure] = [Failure.make(c, doc, field)]
	return out


static func ok() -> Array[Failure]:
	var out: Array[Failure] = []
	return out
