# resources/knowledge/contradiction_pair.gd — JIOH-26: two facts answering the
# same question differently, authored on purpose, with the one the job
# record (and so the validator) agrees with. Never shown to the player.
class_name ContradictionPair
extends Resource

@export var fact_a: StringName = &""
@export var fact_b: StringName = &""
@export var truth: StringName = &""
## Why it exists, for designers.
@export_multiline var note: String = ""
