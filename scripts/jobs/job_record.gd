# scripts/jobs/job_record.gd — one job a trade turns up for. What the
# paperwork for it should say. Authored per day (JIOH-21/28); the validator
# reads it at handout and nothing shows it to the player.
class_name JobRecord
extends Resource

## The job sheet number, e.g. "JS-0412".
@export var job_number: String = ""
@export var trade: StringName = &""
## Selects conditional documents in the pack matrix (e.g. &"cutting").
@export var job_kind: StringName = &"standard"
@export var location: String = ""
@export_multiline var scope: String = ""
## Campaign days the job runs. A two-day job needs paperwork covering both.
@export var start_day: int = 1
@export var end_day: int = 1
## Expected references other documents must carry.
@export var key_number: String = ""
@export var isolation_serial: String = ""
## The job number on the returned sheet from the last visit to this location,
## which the job sheet must quote (paperwork design doc). Empty if none.
@export var previous_job_number: String = ""
