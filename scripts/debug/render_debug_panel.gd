# scripts/debug/render_debug_panel.gd — JIOH-59: live controls for the PS1 look.
#
# Debug builds only: mounted by autoload/debug_hooks.gd, and scenes/debug/ and
# scripts/debug/ are excluded from release exports. Sits on a CanvasLayer in
# the root window, above the display surface and never inside the internal
# viewport. Writes go to RenderConfig at runtime only; the shipped .tres on
# disk is never modified. Toggle with F3 (input action debug_render_panel).
extends CanvasLayer

var _panel: PanelContainer
var _controls: Dictionary = {}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	RenderConfig.config_changed.connect(func(_p): _sync())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_render_panel"):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "PS1 render (F3)"
	box.add_child(title)
	_toggle(box, &"snap_enabled", "Vertex snapping")
	_slider(box, &"snap_resolution", "Snap grid width", 40, 640, 10)
	_toggle(box, &"affine_enabled", "Affine mapping")
	_toggle(box, &"dither_enabled", "Dither")
	_slider(box, &"colour_levels", "Colour levels", 4, 64, 1)
	_toggle(box, &"fog_enabled", "Fog")
	_slider(box, &"fog_density", "Fog density", 0.01, 0.5, 0.01)
	var mode := OptionButton.new()
	for m in PS1Master.InternalMode.keys():
		mode.add_item(m.trim_prefix("MODE_"))
	mode.item_selected.connect(func(i): RenderConfig.set_value(&"internal_mode", i))
	box.add_child(mode)
	_controls[&"internal_mode"] = mode
	var restore := Button.new()
	restore.text = "Restore shipped preset"
	restore.pressed.connect(RenderConfig.restore_shipped)
	box.add_child(restore)
	_sync()


func _toggle(box: Container, property: StringName, label: String) -> void:
	var check := CheckBox.new()
	check.text = label
	check.toggled.connect(func(on): RenderConfig.set_value(property, on))
	box.add_child(check)
	_controls[property] = check


func _slider(box: Container, property: StringName, label: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size.x = 160
	slider.value_changed.connect(func(v):
		if property == &"snap_resolution":
			RenderConfig.set_value(property, Vector2(v, roundf(v * 0.75)))
		else:
			RenderConfig.set_value(property, v))
	row.add_child(slider)
	box.add_child(row)
	_controls[property] = slider


## Reflects RenderConfig without re-triggering writes.
func _sync() -> void:
	var m := RenderConfig.master
	for property in _controls:
		var c: Control = _controls[property]
		if c is CheckBox:
			c.set_pressed_no_signal(m.get(property))
		elif c is HSlider:
			var v = m.get(property)
			c.set_value_no_signal(v.x if v is Vector2 else v)
		elif c is OptionButton:
			c.select(m.get(property))
