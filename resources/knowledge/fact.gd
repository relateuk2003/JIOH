# resources/knowledge/fact.gd — JIOH-26: one thing one or more sources in the
# office say. Sources never invent content; they show the facts that name
# them. A fact is what a source says, not what is true.
class_name Fact
extends Resource

## STATED: plainly given. GARBLED: there, but hard to catch (a mumbled number
## on the answerphone). SUPERSEDED: was true once and is still lying about
## (an old drawing revision, a crossed-out planner entry).
enum Confidence { STATED, GARBLED, SUPERSEDED }

## Every source in the office that carries facts.
const SOURCES: Array[StringName] = [
	&"wall_planner", &"answerphone", &"returned_sheets", &"terminal_mail",
	&"site_drawings", &"key_cabinet", &"key_register", &"permit_register", &"file_store",
]

@export var fact_id: StringName = &""
## job, key, delivery or operative.
@export var subject: StringName = &"job"
## Which job (or key, delivery, operative) it is about: a JobRecord.job_id.
@export var subject_id: StringName = &""
## The document field it answers, e.g. &"job_number".
@export var key: StringName = &""
## Other fields the same fact answers: the job's day is the job sheet's date
## and the permit's valid-from and valid-to.
@export var also_answers: Array[StringName] = []
## Dates are written "day:N" (campaign day N) because the calendar is the
## player's own; sources render them as weekdays and dates.
@export var value: String = ""
## First campaign day the fact can be found.
@export var available_from_day: int = 1
@export var sources: Array[StringName] = []
@export var confidence: Confidence = Confidence.STATED
## How the source puts it, if not just the value: "Thurs - scaffolders back".
@export var wording: String = ""


func answers(field_key: StringName) -> bool:
	return key == field_key or field_key in also_answers


## The campaign day a "day:N" value names, or -1.
func day_value() -> int:
	return int(value.substr(4)) if value.begins_with("day:") else -1
