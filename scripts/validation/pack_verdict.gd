# scripts/validation/pack_verdict.gd — JIOH-29: what the trade makes of a pack.
class_name PackVerdict
extends RefCounted

enum Severity { ACCEPTED, GRUMBLED, REJECTED, WALKED_OFF }

var accepted: bool = true
var failures: Array[Failure] = []
var severity: Severity = Severity.ACCEPTED


func has(code: Failure.Code) -> bool:
	return failures.any(func(f): return f.code == code)


func codes() -> Array[String]:
	var out: Array[String] = []
	for f in failures:
		out.append(f.code_name())
	return out
