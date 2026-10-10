# scripts/rendering/internal_viewport.gd — JIOH-44: the one low-resolution
# render target everything in the game draws into, and the integer upscale
# that presents it.
#
# The SubViewport is sized once from the PS1Master preset and never resized
# for window changes; only its presentation changes. The display surface is
# placed at a whole-number scale with integer offsets, and the rest of the
# window is letterbox colour. Nothing renders directly to the output window.
class_name InternalViewport
extends SubViewport

signal resolution_changed(internal_size: Vector2i, scale_factor: int)

const POST_SHADER := preload("res://shaders/ps1_post.gdshader")

## The TextureRect that shows this viewport in the window.
@export var display: TextureRect
## Fills the window behind the display: the pillarbox and letterbox.
@export var letterbox: ColorRect

var scale_factor: int = 0
var _window_size := Vector2i.ZERO


func _ready() -> void:
	size = RenderConfig.master.internal_size()
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	display.texture = get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var post := ShaderMaterial.new()
	post.shader = POST_SHADER
	display.material = post
	get_tree().root.size_changed.connect(_layout)
	RenderConfig.config_changed.connect(_on_config_changed)
	_on_config_changed(&"")


## The largest whole-number scale at which internal fits inside window.
## Never below 1; a window smaller than the internal image is degenerate.
static func integer_scale(window: Vector2i, internal: Vector2i) -> int:
	return maxi(1, mini(window.x / internal.x, window.y / internal.y))


## Top-left of the display surface, centred with integer offsets.
static func display_origin(window: Vector2i, internal: Vector2i, factor: int) -> Vector2i:
	return (window - internal * factor) / 2


## Converts a window-space position to internal-resolution pixels.
func window_to_internal(p: Vector2) -> Vector2:
	return (p - display.position) / float(scale_factor)


func _on_config_changed(property: StringName) -> void:
	if property == &"" or property == &"internal_mode":
		size = RenderConfig.master.internal_size()
		(display.material as ShaderMaterial).set_shader_parameter(&"internal_size", Vector2(size))
		scale_factor = 0  # force a re-layout and signal
	letterbox.color = RenderConfig.master.letterbox_colour
	_layout()


func _layout() -> void:
	var window := get_tree().root.size
	var factor := integer_scale(window, size)
	display.position = Vector2(display_origin(window, size, factor))
	display.size = Vector2(size * factor)
	if factor != scale_factor or window != _window_size:
		var changed := factor != scale_factor
		scale_factor = factor
		_window_size = window
		if changed:
			resolution_changed.emit(size, scale_factor)
