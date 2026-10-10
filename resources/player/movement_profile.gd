# resources/player/movement_profile.gd — JIOH-46: the controller's tuning.
# Designers tune movement_profile.tres, not the script.
class_name MovementProfile
extends Resource

## Metres per second. There is no sprint.
@export var walk_speed: float = 1.6
@export var acceleration: float = 12.0
@export var friction: float = 16.0
## Radians of turn per pixel of raw mouse motion.
@export var mouse_sensitivity: float = 0.0025
## Metres of vertical head travel at the top of the stride. 0 disables the
## visual bob only; footsteps keep the same cadence.
@export var bob_amplitude: float = 0.035
## Metres walked per full bob cycle (two footsteps).
@export var stride_length: float = 1.5
@export_range(0.0, 89.0) var pitch_limit: float = 80.0
@export var eye_height: float = 1.62
## Only deep enough to reach a low drawer.
@export var crouch_depth: float = 0.55
@export var crouch_speed: float = 3.0
