# tools/affine_test_room.gd — JIOH-51: a corridor for judging the warp budget
# by eye. Left to right: a two-triangle floor (the unacceptable extreme), a
# 4x4 subdivided floor and a 16x16 subdivided floor, same texture on each.
# The camera pans slowly so the swim is visible.
extends Node3D

@export var pan := true
@export var pan_degrees := 20.0
@export var pan_seconds := 8.0

@onready var camera: Camera3D = $Camera3D

var _t := 0.0
var _base_yaw := 0.0


func _ready() -> void:
	_base_yaw = camera.rotation.y
	RenderConfig.apply_camera(camera)
	RenderConfig.config_changed.connect(func(_p): RenderConfig.apply_camera(camera))


func _process(delta: float) -> void:
	if not pan:
		return
	_t += delta
	camera.rotation.y = _base_yaw + deg_to_rad(pan_degrees) * sin(TAU * _t / pan_seconds)
