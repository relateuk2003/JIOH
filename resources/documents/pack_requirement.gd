# resources/documents/pack_requirement.gd — JIOH-20: one row of the pack
# matrix. required_docs are the bold cells: the trade refuses at the hatch
# without them. expected_docs are the plain "Yes" cells: wanted, but the job
# can start without them.
class_name PackRequirement
extends Resource

@export var trade: StringName = &""
## Leave as &"*" to match every job kind for this trade.
@export var job_kind: StringName = &"*"
@export var required_docs: Array[StringName] = []
@export var expected_docs: Array[StringName] = []
@export var conditional_docs: Array[ConditionalDoc] = []
