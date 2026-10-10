# resources/documents/rules/sibling_match_rule.gd — JIOH-29: two documents in
# one pack must agree (the RAMS job number and the job sheet's, the permit's
# isolation serial and the certificate's, the hot works parent number and the
# permit's number). Authored on the template, never hard-coded.
class_name SiblingMatchRule
extends ValidationRule

@export var field_key: StringName = &""
@export var sibling_doc_id: StringName = &""
@export var sibling_field_key: StringName = &""


func evaluate(doc: DocumentInstance, ctx: Dictionary) -> Array[Failure]:
	var mine := normalise(doc.get_value(field_key))
	if mine == "":
		return ok()
	var out: Array[Failure] = []
	for other in ctx.pack:
		var o := other as DocumentInstance
		if o == doc or o.doc_id() != sibling_doc_id:
			continue
		var theirs := normalise(o.get_value(sibling_field_key))
		if theirs != "" and theirs != mine:
			var f := Failure.make(Failure.Code.CONTRADICTS_SIBLING, doc, field_key)
			f.other_instance_id = o.instance_id
			out.append(f)
	return out
