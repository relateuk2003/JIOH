# resources/documents/rules/unclosed_predecessor_rule.gd — JIOH-29 / JIOH-35:
# an earlier permit for the same location that went out and was never closed
# out blocks a new one. The inherited failure: it began on a previous day.
class_name UnclosedPredecessorRule
extends ValidationRule

@export var location_key: StringName = &"location"


func evaluate(doc: DocumentInstance, ctx: Dictionary) -> Array[Failure]:
	var here := normalise(doc.get_value(location_key))
	if here == "":
		return ok()
	for earlier in ctx.get("history", []):
		var e := earlier as DocumentInstance
		if e == doc or e.doc_id() != doc.doc_id() or e.raised_on_day >= doc.raised_on_day:
			continue
		if e.location == CampaignState.Location.HANDED_OVER and not e.closed_out \
				and normalise(e.get_value(location_key)) == here:
			var f := Failure.make(Failure.Code.UNCLOSED_PREDECESSOR, doc, location_key)
			f.other_instance_id = e.instance_id
			var out: Array[Failure] = [f]
			return out
	return ok()
