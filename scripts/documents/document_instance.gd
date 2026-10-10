# scripts/documents/document_instance.gd — JIOH-18: one specific sheet of paper.
#
# A template says what a permit to work is; an instance is the dog-eared one
# the player filled in on Tuesday, stamped with a wheel wound to last Thursday
# and put in the sparks' pigeon hole. Instances record their own history from
# birth because the compounding-error system (JIOH-35) cannot reconstruct it.
#
# Deliberately absent: is_valid(), an errors array, a dirty flag. Paper does
# not know whether it is correct. Correctness comes only from the rules engine
# at handout (JIOH-29). Do not add one.
class_name DocumentInstance
extends RefCounted

var template: DocumentTemplate
var instance_id: StringName = &""
## Field key -> Variant-safe value.
var values: Dictionary = {}
var signature: SignatureMark = null
var stamp: StampMark = null
var punched: bool = false
## Torn by an overloaded punch (JIOH-27). The sheet has to be redone.
var torn: bool = false
## How dark the printer's ribbon printed it, 0..1. Faint is still legible.
var print_quality: float = 1.0
## Where the sheet physically is: a CampaignState.Location value.
var location: int = 0
## The campaign day the pack this belongs to is for, or 0 if unassigned.
var due_day: int = 0

# Provenance, stamped from WorldClock.
var raised_on_day: int = 0
var printed_at_unix: int = 0
var copied_from_instance_id: StringName = &""
var lodged_in_hole: StringName = &""
var lodged_at_unix: int = 0
var returned_on_day: int = -1
var closed_out: bool = false
## The page a held pack was left open at, kept on its first sheet (JIOH-71).
var open_page: int = 0


## Prints a fresh sheet of the given template now.
static func print_new(tpl: DocumentTemplate, copied_from: StringName = &"") -> DocumentInstance:
	var doc := DocumentInstance.new()
	doc.template = tpl
	doc.instance_id = mint_id()
	doc.raised_on_day = WorldClock.get_campaign_day()
	doc.printed_at_unix = WorldClock.now_unix()
	doc.copied_from_instance_id = copied_from
	return doc


## A random v4 UUID.
static func mint_id() -> StringName:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return StringName("%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4),
		h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)])


func doc_id() -> StringName:
	return template.doc_id if template else &""


func set_value(key: StringName, value: Variant) -> void:
	values[key] = value


func get_value(key: StringName, default: Variant = null) -> Variant:
	return values.get(key, default)


func sign(by: StringName) -> void:
	signature = SignatureMark.make(by)


func apply_stamp(stamp_id: StringName, wheel_date: String) -> void:
	stamp = StampMark.make(stamp_id, wheel_date)


func lodge(hole: StringName) -> void:
	lodged_in_hole = hole
	lodged_at_unix = WorldClock.now_unix()


## Plain Variant-safe dictionary. Only the doc_id of the template is saved, so
## a patched template rebinds cleanly on load.
func to_dict() -> Dictionary:
	var vals := {}
	for k in values:
		vals[String(k)] = values[k]
	return {
		"doc_id": String(doc_id()),
		"instance_id": String(instance_id),
		"values": vals,
		"signature": signature.to_dict() if signature else null,
		"stamp": stamp.to_dict() if stamp else null,
		"punched": punched,
		"torn": torn,
		"print_quality": print_quality,
		"location": location,
		"due_day": due_day,
		"raised_on_day": raised_on_day,
		"printed_at_unix": printed_at_unix,
		"copied_from_instance_id": String(copied_from_instance_id),
		"lodged_in_hole": String(lodged_in_hole),
		"lodged_at_unix": lodged_at_unix,
		"returned_on_day": returned_on_day,
		"closed_out": closed_out,
		"open_page": open_page,
	}


## Rebuilds an instance, rebinding to the current template by doc_id. Returns
## null if no template with that doc_id is registered.
static func from_dict(d: Dictionary) -> DocumentInstance:
	var tpl := DocumentRegistry.get_template(StringName(d.get("doc_id", "")))
	if tpl == null:
		push_error("DocumentInstance.from_dict: unknown doc_id '%s'" % d.get("doc_id", ""))
		return null
	var doc := DocumentInstance.new()
	doc.template = tpl
	doc.instance_id = StringName(d.get("instance_id", ""))
	var vals: Dictionary = d.get("values", {})
	for k in vals:
		doc.values[StringName(k)] = vals[k]
	if d.get("signature") is Dictionary:
		doc.signature = SignatureMark.from_dict(d.signature)
	if d.get("stamp") is Dictionary:
		doc.stamp = StampMark.from_dict(d.stamp)
	doc.punched = bool(d.get("punched", false))
	doc.torn = bool(d.get("torn", false))
	doc.print_quality = float(d.get("print_quality", 1.0))
	doc.location = int(d.get("location", 0))
	doc.due_day = int(d.get("due_day", 0))
	doc.raised_on_day = int(d.get("raised_on_day", 0))
	doc.printed_at_unix = int(d.get("printed_at_unix", 0))
	doc.copied_from_instance_id = StringName(d.get("copied_from_instance_id", ""))
	doc.lodged_in_hole = StringName(d.get("lodged_in_hole", ""))
	doc.lodged_at_unix = int(d.get("lodged_at_unix", 0))
	doc.returned_on_day = int(d.get("returned_on_day", -1))
	doc.closed_out = bool(d.get("closed_out", false))
	doc.open_page = int(d.get("open_page", 0))
	return doc
