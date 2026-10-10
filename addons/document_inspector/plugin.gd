# addons/document_inspector/plugin.gd — JIOH-18: lists every DocumentTemplate
# with its form code, trades and fields, so the pack matrix can be eyeballed
# without opening each .tres. (Godot only loads editor plugins from addons/,
# so this lives here rather than under tools/.)
@tool
extends EditorPlugin

const TEMPLATE_DIR := "res://resources/documents/templates/"

var _dock: VBoxContainer
var _tree: Tree


func _enter_tree() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "Documents"
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(_refresh)
	_dock.add_child(refresh)
	_tree = Tree.new()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Template / field")
	_tree.set_column_title(1, "Form / type")
	_tree.set_column_title(2, "Trades / source")
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(_tree)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_refresh()


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _refresh() -> void:
	_tree.clear()
	var root := _tree.create_item()
	if not DirAccess.dir_exists_absolute(TEMPLATE_DIR):
		return
	for file in ResourceLoader.list_directory(TEMPLATE_DIR):
		if not file.ends_with(".tres"):
			continue
		var tpl := load(TEMPLATE_DIR.path_join(file)) as DocumentTemplate
		if tpl == null:
			continue
		var item := _tree.create_item(root)
		item.set_text(0, "%s (%s)" % [tpl.display_name, tpl.doc_id])
		item.set_text(1, tpl.form_code)
		item.set_text(2, ", ".join(tpl.trades.map(func(t): return String(t))))
		for f in tpl.fields:
			var child := _tree.create_item(item)
			child.set_text(0, ("* " if f.required else "  ") + f.printed_label)
			child.set_text(1, DocumentField.FieldType.keys()[f.type])
			child.set_text(2, String(f.source_hint))
		item.collapsed = true
