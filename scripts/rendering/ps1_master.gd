# scripts/rendering/ps1_master.gd — JIOH-59: every knob of the PS1 look in one
# resource. Every uniform introduced by a rendering ticket is surfaced here
# and nowhere else. resources/environment/ps1_master_shipped.tres is the
# single shipped preset and the authoritative record of the look.
class_name PS1Master
extends Resource

enum InternalMode { MODE_320x240, MODE_320x256, MODE_512x240 }

const INTERNAL_SIZES := {
	InternalMode.MODE_320x240: Vector2i(320, 240),
	InternalMode.MODE_320x256: Vector2i(320, 256),
	InternalMode.MODE_512x240: Vector2i(512, 240),
}

@export_group("Snapping")  # JIOH-47
@export var snap_enabled: bool = true
## Virtual grid the vertices snap to. Lower wobbles harder.
@export var snap_resolution: Vector2 = Vector2(160, 120)

@export_group("Affine")  # JIOH-51
@export var affine_enabled: bool = true

@export_group("Colour")  # JIOH-55
@export var dither_enabled: bool = true
## Levels per channel: 32 is true 15-bit output.
@export_range(2, 256) var colour_levels: float = 32.0

@export_group("Fog")  # JIOH-55
@export var fog_enabled: bool = true
## Also the clear colour, so fogged geometry dissolves into the background.
@export var fog_colour: Color = Color(0.09, 0.09, 0.08)
@export_range(0.001, 1.0, 0.001) var fog_density: float = 0.12

@export_group("Viewport")  # JIOH-44
@export var internal_mode: InternalMode = InternalMode.MODE_320x240
@export var letterbox_colour: Color = Color(0, 0, 0)


func internal_size() -> Vector2i:
	return INTERNAL_SIZES[internal_mode]


## The camera far plane: just past the distance at which exponential fog
## saturates (under 1/256 of the surface colour left), so nothing is ever
## seen to clip.
func far_plane() -> float:
	if not fog_enabled:
		return 100.0
	return log(256.0) / fog_density * 1.05
