# resources/documents/document_field.gd — JIOH-18: one printed field on a sheet.
class_name DocumentField
extends Resource

enum FieldType { TEXT, NUMBER, DATE, TIME, REFERENCE, TICKBOX, SIGNATURE, MULTILINE }

@export var key: StringName = &""
@export var printed_label: String = ""
@export var type: FieldType = FieldType.TEXT
@export var required: bool = false
@export var max_length: int = 0
## Position on the sheet in paper-local UV space (0..1).
@export var rect: Rect2 = Rect2()
## Which information source (JIOH-26) holds the answer. Authoring tools only;
## never shown to the player.
@export var source_hint: StringName = &""
