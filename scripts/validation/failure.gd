# scripts/validation/failure.gd — JIOH-29: one thing wrong with a pack.
class_name Failure
extends RefCounted

## Closed list. Adding a code needs a spoken line in hatch_lines.tres and a
## test fixture in tests/validation/.
enum Code {
	MISSING_FIELD, WRONG_DATE_IN_FIELD, WRONG_DATE_ON_STAMP, WRONG_TRADE,
	WRONG_JOB_NUMBER, UNSIGNED, UNSTAMPED, UNPUNCHED, EXPIRED, MISSING_DOCUMENT,
	SURPLUS_DOCUMENT, CONTRADICTS_SIBLING, UNCLOSED_PREDECESSOR, WRONG_PIGEON_HOLE,
}

var code: Code
var instance_id: StringName = &""
## The other sheet, for CONTRADICTS_SIBLING.
var other_instance_id: StringName = &""
var field_key: StringName = &""
## For MISSING_DOCUMENT: the doc_id that should have been there.
var doc_id: StringName = &""
## A missing document the job cannot proceed without (bold in the matrix).
var blocking: bool = false
var spoken_line_id: StringName = &""


static func make(c: Code, doc: DocumentInstance = null, field: StringName = &"") -> Failure:
	var f := Failure.new()
	f.code = c
	if doc:
		f.instance_id = doc.instance_id
		f.doc_id = doc.doc_id()
	f.field_key = field
	f.spoken_line_id = StringName("hatch_" + Code.keys()[c].to_lower())
	return f


func code_name() -> String:
	return Code.keys()[code]


func to_dict() -> Dictionary:
	return {"code": code_name(), "instance_id": String(instance_id), "other_instance_id": String(other_instance_id),
		"field_key": String(field_key), "doc_id": String(doc_id), "blocking": blocking,
		"spoken_line_id": String(spoken_line_id)}


static func from_dict(d: Dictionary) -> Failure:
	var f := Failure.new()
	f.code = Code.keys().find(d.get("code", "MISSING_FIELD")) as Code
	f.instance_id = StringName(d.get("instance_id", ""))
	f.other_instance_id = StringName(d.get("other_instance_id", ""))
	f.field_key = StringName(d.get("field_key", ""))
	f.doc_id = StringName(d.get("doc_id", ""))
	f.blocking = bool(d.get("blocking", false))
	f.spoken_line_id = StringName(d.get("spoken_line_id", ""))
	return f
