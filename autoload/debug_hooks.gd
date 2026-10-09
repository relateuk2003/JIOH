# autoload/debug_hooks.gd — mounts developer tools in debug builds only.
#
# Release export presets exclude tools/debug/ entirely (JIOH-25), so the
# console is loaded by path here rather than registered as an autoload: a
# missing autoload would be a boot error, a missing optional file is not.
extends Node

const TIME_CONSOLE := "res://tools/debug/time_console.tscn"


func _ready() -> void:
	if not OS.has_feature("debug"):
		return
	if not ResourceLoader.exists(TIME_CONSOLE):
		return
	var console: Node = (load(TIME_CONSOLE) as PackedScene).instantiate()
	add_child.call_deferred(console)
