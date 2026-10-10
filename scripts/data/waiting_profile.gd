# scripts/data/waiting_profile.gd — JIOH-37: how a trade waits at an empty
# hatch. The ladder is shared; this says which rungs a character skips.
class_name WaitingProfile
extends Resource

## Bit per WaitingBehaviour.LADDER entry; a cleared bit skips that beat. The
## departure is never skippable.
@export var beat_mask: int = 0xFF
@export var knock_style: StringName = &"rap"
@export var leaves_note: bool = true
@export var uses_phone: bool = true
## Says a waiting line under their breath now and then.
@export var mutters: bool = false
