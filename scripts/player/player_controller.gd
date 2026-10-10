# scripts/player/player_controller.gd — JIOH-46: a first-person controller
# that belongs to 1998.
#
# No sprint (there is no sprint action at all), raw unsmoothed mouse look,
# and a head bob that is a fixed sine driven by distance walked: stop walking
# and the bob stops mid-stride, stand still and the camera is perfectly still.
# Footsteps fire from the bob phase, so turning the bob off keeps the cadence.
class_name PlayerController
extends CharacterBody3D

## Fires on each footfall with the floor collider's "surface" metadata.
signal footstep(surface: StringName)

@export var profile: MovementProfile = preload("res://resources/player/movement_profile.tres")

@onready var head: Node3D = $Head
@onready var eye: Camera3D = $Head/Eye

var movement_locked := false
## Scales walking speed: reading a held document shuffles (JIOH-71).
var speed_scale := 1.0
## Distance walked, in metres. Drives the bob phase.
var stride_distance := 0.0
## When set, overrides keyboard input. Tests and cutscenes drive the body
## through this rather than through fake key events.
var scripted_input: Variant = null

var _crouch := 0.0
var _last_half_stride := 0


func _ready() -> void:
	head.position = Vector3(0, profile.eye_height, 0)
	RenderConfig.apply_camera(eye)
	InteractionManager.register_player(self)
	RenderConfig.config_changed.connect(func(_p): RenderConfig.apply_camera(eye))


## Freezes the body while leaving mouse look live (examine, cutscenes).
func set_movement_locked(locked: bool) -> void:
	movement_locked = locked


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif event.is_action_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Applies raw mouse motion in pixels. No smoothing, no acceleration, no
## per-frame lerp: the same physical motion gives the same turn at any
## frame rate.
func look(relative: Vector2) -> void:
	rotation.y -= relative.x * profile.mouse_sensitivity
	var limit := deg_to_rad(profile.pitch_limit)
	head.rotation.x = clampf(head.rotation.x - relative.y * profile.mouse_sensitivity, -limit, limit)


## Turns the view part of the way toward a point over a moment: the one soft
## nudge when someone at the hatch first speaks (JIOH-30). Never a lock; the
## player can turn straight back.
func nudge_toward(point: Vector3, seconds := 0.4, share := 0.4) -> void:
	var to := point - eye.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var dyaw := wrapf(yaw - rotation.y, -PI, PI) * share
	var dpitch := (pitch - head.rotation.x) * share
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rotation:y", rotation.y + dyaw, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation:x", head.rotation.x + dpitch, seconds).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	var input := _move_input()
	var wish := (global_basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * profile.walk_speed * speed_scale
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := profile.acceleration if target.length() > 0.0 else profile.friction
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta

	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if is_on_floor():
		stride_distance += moved
	_update_bob()
	_update_crouch(delta)


func _move_input() -> Vector2:
	if movement_locked:
		return Vector2.ZERO
	if scripted_input != null:
		return scripted_input
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _update_bob() -> void:
	var phase := stride_distance / profile.stride_length * TAU
	head.position.y = profile.eye_height - _crouch + absf(sin(phase)) * profile.bob_amplitude
	head.position.x = sin(phase) * profile.bob_amplitude * 0.5
	# A footfall each half stride, when the vertical bob touches bottom.
	var half_strides := floori(stride_distance / (profile.stride_length * 0.5))
	if half_strides != _last_half_stride:
		_last_half_stride = half_strides
		footstep.emit(_floor_surface())


func _update_crouch(delta: float) -> void:
	var want := profile.crouch_depth if (not movement_locked and Input.is_action_pressed(&"crouch")) else 0.0
	_crouch = move_toward(_crouch, want, profile.crouch_speed * delta)


func _floor_surface() -> StringName:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7 and c.get_collider() and c.get_collider().has_meta(&"surface"):
			return StringName(c.get_collider().get_meta(&"surface"))
	return &"default"
