# autoload/document_registry.gd — JIOH-18: every DocumentTemplate, by doc_id.
#
# Loads each resource under resources/documents/templates/ once at boot, so a
# designer adds a document type by dropping in a .tres with no code change.
extends Node

const TEMPLATE_DIR := "res://resources/documents/templates/"

var _templates: Dictionary = {}


func _ready() -> void:
	load_directory(TEMPLATE_DIR)


func load_directory(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	# list_directory sees through export remapping (.tres -> .res.remap).
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with("/") or not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var tpl := load(dir.path_join(file)) as DocumentTemplate
		if tpl == null:
			push_error("DocumentRegistry: %s is not a DocumentTemplate" % file)
			continue
		register_template(tpl)


func register_template(tpl: DocumentTemplate) -> void:
	if tpl.doc_id == &"":
		push_error("DocumentRegistry: template '%s' has no doc_id" % tpl.resource_path)
		return
	_templates[tpl.doc_id] = tpl


func get_template(doc_id: StringName) -> DocumentTemplate:
	return _templates.get(doc_id)


func has_template(doc_id: StringName) -> bool:
	return _templates.has(doc_id)


func all_templates() -> Array[DocumentTemplate]:
	var out: Array[DocumentTemplate] = []
	for t in _templates.values():
		out.append(t)
	return out


## Prints a new sheet of a registered type.
func print_document(doc_id: StringName, copied_from: StringName = &"") -> DocumentInstance:
	var tpl := get_template(doc_id)
	if tpl == null:
		push_error("DocumentRegistry: no template '%s'" % doc_id)
		return null
	return DocumentInstance.print_new(tpl, copied_from)
