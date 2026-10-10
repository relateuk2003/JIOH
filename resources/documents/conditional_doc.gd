# resources/documents/conditional_doc.gd — JIOH-20: a document a job needs
# only when its kind says so (hot works when the carpenter is cutting).
class_name ConditionalDoc
extends Resource

@export var doc_id: StringName = &""
@export var when_job_kind_in: Array[StringName] = []
## True if the job cannot start without it.
@export var blocking: bool = true
