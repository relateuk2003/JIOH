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
