# resources/documents/document_template.gd — JIOH-18: the authored, immutable
# description of a document type. One .tres per type under
# resources/documents/templates/. Instances (DocumentInstance) refer back to a
# template by doc_id and never copy its data.
class_name DocumentTemplate
extends Resource

@export var doc_id: StringName = &""
@export var display_name: String = ""
## The printed reference on the sheet, e.g. "PTW-04/B".
@export var form_code: String = ""
@export var trades: Array[StringName] = []
@export var fields: Array[DocumentField] = []
@export var requires_signature: bool = false
@export var requires_stamp: bool = false
## Sheets that are filed rather than lodged must be punched first.
@export var requires_punch: bool = false
## -1 for no expiry.
@export var validity_days: int = -1
@export var paper_scene: PackedScene
## A handwritten sheet (Janice's note) instead of a printed form: no boxes,
## the instance's "sheet" value says which page of the writing it is.
@export var handwriting: HandwrittenText
@export var validation_rules: Array[ValidationRule] = []


func get_field(key: StringName) -> DocumentField:
	for f in fields:
		if f.key == key:
			return f
	return null
