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


## Saved with a read in progress, so a reload delivers this verdict rather
## than scoring the pack again (JIOH-30).
func to_dict() -> Dictionary:
	return {"accepted": accepted, "severity": int(severity), "failures": failures.map(func(f): return f.to_dict())}


static func from_dict(d: Dictionary) -> PackVerdict:
	var v := PackVerdict.new()
	v.accepted = bool(d.get("accepted", true))
	v.severity = int(d.get("severity", 0)) as Severity
	for f in d.get("failures", []):
		v.failures.append(Failure.from_dict(f))
	return v
