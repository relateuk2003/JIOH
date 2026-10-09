# scripts/data/body_profile_data.gd — JIOH-21: build, kit and gait. The
# blank-face model (JIOH-48) reads these; until then the hatch silhouette
# uses height, build and colour so trades are told apart at a glance.
class_name BodyProfileData
extends Resource

enum Build { SLIGHT, AVERAGE, STOCKY, HEAVY }

@export var body_id: StringName = &""
@export var height_m: float = 1.78
@export var build: Build = Build.AVERAGE
## Metres per second walking to the hatch.
@export var gait_speed: float = 1.3
## Hi-vis, overalls, polo: the colour seen through frosted glass first.
@export var kit_colour: Color = Color(0.3, 0.3, 0.35)
@export_multiline var kit_notes: String = ""
## How they stand at the hatch while waiting (lean, fidget, still).
@export var waiting_pose: StringName = &"still"
