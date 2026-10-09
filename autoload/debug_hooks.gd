# autoload/debug_hooks.gd — mounts developer tools in debug builds only.
#
# Release export presets exclude tools/debug/, scenes/debug/ and
# scripts/debug/ entirely (JIOH-25, JIOH-59), so these are loaded by path here
# rather than registered as autoloads: a missing autoload would be a boot
# error, a missing optional file is not.
extends Node

const TOOLS := [
	"res://tools/debug/time_console.tscn",  # JIOH-25
	"res://scenes/debug/render_debug_panel.tscn",  # JIOH-59
]


func _ready() -> void:
	if not OS.has_feature("debug"):
		return
	for path in TOOLS:
		if ResourceLoader.exists(path):
			add_child.call_deferred((load(path) as PackedScene).instantiate())
