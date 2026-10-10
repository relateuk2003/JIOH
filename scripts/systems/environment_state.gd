# scripts/systems/environment_state.gd — the building's systems as the
# calendar sets them. A seed of the environmental state ticket: for now it
# only knows that at the weekend the building is off.
class_name EnvironmentState
extends RefCounted


## Saturday or Sunday, by the game clock.
static func is_weekend() -> bool:
	var wd: int = WorldClock.get_now().weekday
	return wd == 0 or wd == 6
