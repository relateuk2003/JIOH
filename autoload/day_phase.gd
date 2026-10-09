# autoload/day_phase.gd — JIOH-16: the working day as one state machine.
#
# Driven only by WorldClock.minute_elapsed; it never runs its own timer. On
# each tick it walks every boundary between the last time it looked and now,
# in order, so a player who comes back at 17:00 having left at 08:00 still
# sees HANDOUT, WORKING, CUTOFF and WIND_DOWN fire once each, in sequence.
# Day rolls are emitted from the same walk (as WorldClock.day_rolled) so they
# interleave correctly with phase changes.
extends Node

## Emitted for every transition, in timeline order. The only way other systems
## learn about phases.
signal phase_changed(from: Phase, to: Phase)

enum Phase { CLOSED, PRE_OPEN, HANDOUT, WORKING, CUTOFF, WIND_DOWN }

const SCHEDULE_PATH := "res://resources/campaign/day_schedule.tres"
## Longest absence walked boundary by boundary. Anything older is skipped to
## this window; the campaign is only fourteen days long.
const MAX_WALK_DAYS := 20

var schedule: DaySchedule
var phase: Phase = Phase.CLOSED
var _last_unix: int = 0
var _last_day: int = 0


func _ready() -> void:
	schedule = load(SCHEDULE_PATH) as DaySchedule
	WorldClock.minute_elapsed.connect(_on_minute_elapsed)
	CampaignState.campaign_started.connect(resync)
	resync()


## Adopts the current time silently, firing nothing. Used at boot, at New Game
## and after a developer rewinds the clock.
func resync() -> void:
	_last_unix = WorldClock.now_unix()
	_last_day = CampaignState.campaign_day_for(_last_unix)
	phase = phase_at(_last_unix)


## Rewinds the machine to a past instant (e.g. the last autosave) and walks
## forward to now, firing every boundary crossed. JIOH-17 builds on this.
func reconcile_from(last_unix: int) -> void:
	_last_unix = last_unix
	_last_day = CampaignState.campaign_day_for(last_unix)
	phase = phase_at(last_unix)
	_walk_to(WorldClock.now_unix())


## The phase in force at a UTC instant.
func phase_at(utc: int) -> Phase:
	if not CampaignState.is_working_day_at(utc):
		return Phase.CLOSED
	var minute := WorldClock.local_minute_of_day(utc)
	var result := Phase.CLOSED
	for b in schedule.boundaries():
		if minute >= b.x:
			result = b.y as Phase
	return result


func seconds_until_next_phase() -> float:
	var now := WorldClock.now_unix()
	var start_day := WorldClock.local_epoch_day(now)
	for t in _boundary_instants(start_day, start_day + 8):
		if t > now and phase_at(t) != phase:
			return float(t - now)
	return INF


static func phase_name(p: Phase) -> String:
	return Phase.keys()[p].to_lower()


func _on_minute_elapsed() -> void:
	_walk_to(WorldClock.now_unix())


func _walk_to(now: int) -> void:
	if now < _last_unix:
		# Time went backwards: a developer rewind or a tampered clock (JIOH-19).
		resync()
		return
	var from := maxi(_last_unix, now - MAX_WALK_DAYS * WorldClock.SECONDS_PER_DAY)
	var first_day := WorldClock.local_epoch_day(from)
	var last_day := WorldClock.local_epoch_day(now)
	for t in _boundary_instants(first_day, last_day):
		if t <= _last_unix or t > now:
			continue
		_advance_to(t)
	_advance_to(now)
	_last_unix = now


func _advance_to(t: int) -> void:
	var day := CampaignState.campaign_day_for(t)
	if day != _last_day:
		_last_day = day
		WorldClock.day_rolled.emit(day)
	var next := phase_at(t)
	if next != phase:
		var prev := phase
		phase = next
		phase_changed.emit(prev, next)


## Every local midnight and schedule boundary from first_day to last_day
## inclusive, as sorted UTC instants.
func _boundary_instants(first_day: int, last_day: int) -> Array[int]:
	var out: Array[int] = []
	for d in range(first_day, last_day + 1):
		var midnight := WorldClock.utc_of_local_midnight(d)
		out.append(midnight)
		for b in schedule.boundaries():
			out.append(midnight + b.x * 60)
	out.sort()
	return out
