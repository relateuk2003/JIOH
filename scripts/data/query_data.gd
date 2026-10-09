# scripts/data/query_data.gd — JIOH-34: one live question at the hatch. Always
# traceable to a real failure in the pack: the fault it came from, what would
# answer it, and the line that asks it.
class_name QueryData
extends RefCounted

var fault_id: StringName = &""
## Documents that answer it if handed over within the window.
var accepted_document_types: Array[StringName] = []
## For a blank box: the field that must be filled on the handed document.
var field_key: StringName = &""
var voice_line_id: StringName = &""


static func from_failure(f: Failure) -> QueryData:
	var q := QueryData.new()
	q.fault_id = StringName(f.code_name())
	q.voice_line_id = f.spoken_line_id
	q.accepted_document_types = [f.doc_id]
	if f.code == Failure.Code.MISSING_FIELD:
		q.field_key = f.field_key
	return q


## Whether a handed-over sheet answers the question.
func answered_by(doc: DocumentInstance) -> bool:
	if not doc.doc_id() in accepted_document_types:
		return false
	if field_key == &"":
		return true
	var v: Variant = doc.get_value(field_key)
	return v != null and str(v).strip_edges() != "" and str(v) != "false"


func to_dict() -> Dictionary:
	return {"fault_id": String(fault_id), "types": accepted_document_types.map(func(t): return String(t)),
		"field_key": String(field_key), "voice_line_id": String(voice_line_id)}


static func from_dict(d: Dictionary) -> QueryData:
	var q := QueryData.new()
	q.fault_id = StringName(d.get("fault_id", ""))
	for t in d.get("types", []):
		q.accepted_document_types.append(StringName(t))
	q.field_key = StringName(d.get("field_key", ""))
	q.voice_line_id = StringName(d.get("voice_line_id", ""))
	return q
