# scripts/slice/day_open_fmv.gd — JIOH-84: the footage that opens the day.
#
# Once, the first time the player is in the office during the opening of
# the working day (pre-open or handout), resources/fmv/day_open.ogv plays.
# Never again after that, quit mid-video included: FMVPlayer marks it seen
# when it starts. Until the footage exists this does nothing.
class_name DayOpenFMV
extends Node

const PATH := "res://resources/fmv/day_open.ogv"

var played := false


func _ready() -> void:
	DayPhase.phase_changed.connect(func(_f, _t): _maybe_play())
	_maybe_play.call_deferred()


func _maybe_play() -> void:
	if played or not ResourceLoader.exists(PATH):
		return
	if DayPhase.phase != DayPhase.Phase.PRE_OPEN and DayPhase.phase != DayPhase.Phase.HANDOUT:
		return
	if CampaignState.has_viewed_fmv(&"day_open"):
		return
	played = true
	FMVPlayer.spawn(get_parent()).play(PATH, false)
