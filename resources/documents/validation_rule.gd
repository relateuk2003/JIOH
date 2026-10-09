# resources/documents/validation_rule.gd — JIOH-18: the base type templates
# hold their rules as. The rules engine itself is JIOH-29 ("Silent validation
# and the deferred-consequence model"); it runs at handout time only.
class_name ValidationRule
extends Resource

## The failure taxonomy from the paperwork design doc.
enum Category { ABSENT, INCOMPLETE, EXPIRED, CONTRADICTORY, INHERITED }

@export var rule_id: StringName = &""
@export var category: Category = Category.INCOMPLETE
## What the trade says at the hatch when this rule fails.
@export_multiline var refusal_line: String = ""
