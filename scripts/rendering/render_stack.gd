# scripts/rendering/render_stack.gd — JIOH-44: the root presentation scene.
#
# Holds the letterbox, the display surface and the InternalViewport, and
# instances the game world inside the viewport. Mouse input is re-expressed in
# internal-resolution coordinates before it reaches the world, so picking and
# cursor positions are correct at 320x240.
extends Control

## The scene drawn into the internal viewport.
@export var world_scene: PackedScene

@onready var viewport: InternalViewport = $InternalViewport


func _ready() -> void:
	if world_scene:
		viewport.add_child(world_scene.instantiate())


# Forwarded from _unhandled_input so root-level debug overlays (the time
# console, the render panel) see input first.
func _unhandled_input(event: InputEvent) -> void:
	var e := event
	if event is InputEventMouse:
		e = event.duplicate()
		e.position = viewport.window_to_internal(event.position)
		e.global_position = e.position
	viewport.push_input(e, true)
