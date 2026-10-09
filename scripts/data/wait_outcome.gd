# scripts/data/wait_outcome.gd — JIOH-37: where a wait has got to at a given
# stamp. What simulate_to() returns, for the live hatch and for replay alike.
class_name WaitOutcome
extends RefCounted

## Beats reached by the stamp, in order, each {beat, unix}.
var beats: Array[Dictionary] = []
var departed: bool = false
var departed_unix: int = 0
var left_note: bool = false


func last_beat() -> StringName:
	return beats.back().beat if not beats.is_empty() else &""
