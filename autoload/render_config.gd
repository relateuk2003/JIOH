# autoload/render_config.gd — JIOH-59: applies the PS1Master preset.
#
# Loads the shipped preset at boot and writes it to global shader parameters
# (one write reaches every material) and to the shared PS1 environment.
# Runtime changes from the debug panel go through set_value() and never touch
# the .tres on disk; changing the shipped look is a deliberate editor edit.
extends Node

signal config_changed(property: StringName)

const SHIPPED_PATH := "res://resources/environment/ps1_master_shipped.tres"
const ENVIRONMENT_PATH := "res://resources/environment/ps1_environment.tres"

var master: PS1Master
var environment: Environment


func _ready() -> void:
	environment = load(ENVIRONMENT_PATH) as Environment
	restore_shipped()


## Reloads the shipped preset from disk and re-applies every property.
func restore_shipped() -> void:
	var shipped := ResourceLoader.load(SHIPPED_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PS1Master
	master = shipped.duplicate() as PS1Master
	for p in _properties():
		_apply(p)
	config_changed.emit(&"")


func set_value(property: StringName, value: Variant) -> void:
	master.set(property, value)
	_apply(property)
	config_changed.emit(property)


## Points a camera's far plane at the fog's saturation distance.
func apply_camera(camera: Camera3D) -> void:
	camera.far = master.far_plane()


func _apply(property: StringName) -> void:
	match property:
		&"snap_enabled":
			RenderingServer.global_shader_parameter_set(&"ps1_snap_enabled", master.snap_enabled)
		&"snap_resolution":
			RenderingServer.global_shader_parameter_set(&"ps1_snap_resolution", master.snap_resolution)
		&"affine_enabled":
			RenderingServer.global_shader_parameter_set(&"ps1_affine_enabled", master.affine_enabled)
		&"dither_enabled":
			RenderingServer.global_shader_parameter_set(&"ps1_dither_enabled", master.dither_enabled)
		&"colour_levels":
			RenderingServer.global_shader_parameter_set(&"ps1_colour_levels", master.colour_levels)
		&"fog_enabled", &"fog_colour", &"fog_density":
			environment.fog_enabled = master.fog_enabled
			environment.fog_density = master.fog_density
			environment.fog_light_color = master.fog_colour
			environment.background_color = master.fog_colour


func _properties() -> Array[StringName]:
	return [&"snap_enabled", &"snap_resolution", &"affine_enabled", &"dither_enabled",
		&"colour_levels", &"fog_enabled", &"fog_colour", &"fog_density",
		&"internal_mode", &"letterbox_colour"]
