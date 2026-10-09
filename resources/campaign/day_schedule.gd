# resources/campaign/day_schedule.gd — JIOH-16: the shape of a working day.
# Boundaries are minutes after local midnight. Tune them in day_schedule.tres,
# not in code.
class_name DaySchedule
extends Resource

@export_range(0, 1439) var pre_open_minute: int = 6 * 60 + 30
@export_range(0, 1439) var handout_minute: int = 7 * 60 + 30
@export_range(0, 1439) var working_minute: int = 10 * 60
@export_range(0, 1439) var cutoff_minute: int = 15 * 60 + 30
@export_range(0, 1439) var wind_down_minute: int = 16 * 60 + 30
@export_range(0, 1439) var closed_minute: int = 18 * 60


## Boundary minutes in day order, paired with the phase each one opens.
## Phase values match DayPhase.Phase.
func boundaries() -> Array[Vector2i]:
	return [
		Vector2i(pre_open_minute, 1),
		Vector2i(handout_minute, 2),
		Vector2i(working_minute, 3),
		Vector2i(cutoff_minute, 4),
		Vector2i(wind_down_minute, 5),
		Vector2i(closed_minute, 0),
	]
