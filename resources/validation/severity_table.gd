# resources/validation/severity_table.gd — JIOH-29: how bad each failure is.
# Tuned in severity_table.tres. A verdict takes the worst severity in its
# failure set.
class_name SeverityTable
extends Resource

## Failure.Code name -> PackVerdict.Severity.
@export var severities: Dictionary = {}
## A document the matrix expects but the job can start without.
@export var missing_optional: PackVerdict.Severity = PackVerdict.Severity.GRUMBLED
## A document the job cannot start without.
@export var missing_blocking: PackVerdict.Severity = PackVerdict.Severity.WALKED_OFF


func severity_of(f: Failure) -> PackVerdict.Severity:
	if f.code == Failure.Code.MISSING_DOCUMENT:
		return missing_blocking if f.blocking else missing_optional
	return severities.get(f.code_name(), PackVerdict.Severity.REJECTED)
