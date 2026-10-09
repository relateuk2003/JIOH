# autoload/world_clock.gd — JIOH-14: the single source of truth for time.
#
# Every system asks WorldClock for the time. Nothing else in the codebase may
# call Time.get_* (tools/check_time_calls.sh enforces this). That indirection
# is what lets the debug console (JIOH-25) and the soak test move the whole
# world consistently: shift the offset here and every phase, day, stamp and
# schedule shifts with it.
#
# Time is stored as UTC unix seconds and presented as the player's local wall
# time. "Game time" is real OS time plus the debug offset, optionally scaled
# (freeze / fast-forward) for developer use.
extends Node

## Fires once per poll in which the wall-clock minute has changed. Subscribers
## read get_now(); a jump of several hours still fires this once, and DayPhase
## walks the intervening boundaries itself.
signal minute_elapsed
## Fires once per campaign day boundary crossed, in timeline order. Emitted by
## DayPhase while it walks the timeline, so day rolls interleave correctly with
## phase changes (the 18:00 close fires before the next day's roll).
signal day_rolled(new_day: int)

const SECONDS_PER_DAY := 86400
const POLL_INTERVAL := 1.0

## Debug seam (JIOH-25): game time minus real time, in seconds. Read-only from
## outside; change it with set_debug_offset().
var offset_seconds: float:
	get:
		return _game_utc_at(_real_utc()) - _real_utc()

## Developer-only rate control (JIOH-25): 0 freezes, 1 is real time, n is
## n-times fast-forward.
var time_scale: float = 1.0:
	set(value):
		_rebase()
		time_scale = maxf(value, 0.0)

# Game time is _anchor_game + (real - _anchor_real) * time_scale. Re-anchoring
# whenever the offset or scale changes means a thaw resumes without a jump.
var _anchor_real: float = 0.0
var _anchor_game: float = 0.0
var _time_source: Callable = Callable()
var _tz_bias_override: Variant = null
var _accum := 0.0
var _cached_utc: float = 0.0
var _last_minute: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_anchor_real = _real_utc()
	_anchor_game = _anchor_real
	_cached_utc = _anchor_game
	_last_minute = _minute_of(_cached_utc)


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_INTERVAL:
		_accum = 0.0
		poll()


## Re-reads the OS clock and emits minute_elapsed if the minute changed. Called
## once a second by _process; tests and the soak call it directly.
func poll() -> void:
	_cached_utc = _game_utc_at(_real_utc())
	var minute := _minute_of(_cached_utc)
	if minute != _last_minute:
		_last_minute = minute
		minute_elapsed.emit()


# --- Public surface ---------------------------------------------------------

## Current game time as UTC unix seconds (cached at the last poll).
func now_unix() -> int:
	return int(floor(_cached_utc))


## Current local wall time: year, month, day, weekday, hour, minute, second,
## plus unix_utc and unix_local.
func get_now() -> Dictionary:
	return datetime_local(now_unix())


func get_campaign_day() -> int:
	return CampaignState.campaign_day_for(now_unix())


func is_working_day() -> bool:
	return CampaignState.is_working_day_at(now_unix())


func get_phase() -> int:
	return DayPhase.phase


func seconds_until_next_phase() -> float:
	return DayPhase.seconds_until_next_phase()


## Moves game time to real time + offset. The single seam the debug console
## drives. Callers poll() afterwards to have boundaries fire.
func set_debug_offset(seconds: float) -> void:
	var real := _real_utc()
	_anchor_real = real
	_anchor_game = real + seconds


## Moves game time to an absolute UTC instant by setting the offset. Absolute,
## so repeated jumps to the same target cannot accumulate error.
func jump_to(utc: float) -> void:
	set_debug_offset(utc - _real_utc())


# --- Local time helpers -----------------------------------------------------
# Date maths lives here so no other file needs Time.get_*.

## Local-time bias from UTC, in minutes.
func tz_bias_minutes() -> int:
	if _tz_bias_override != null:
		return int(_tz_bias_override)
	return int(Time.get_time_zone_from_system().get("bias", 0))


func to_local_unix(utc: int) -> int:
	return utc + tz_bias_minutes() * 60


func to_utc_unix(local_unix: int) -> int:
	return local_unix - tz_bias_minutes() * 60


## Days since 1970-01-01 of the local date at utc.
func local_epoch_day(utc: int) -> int:
	return floori(float(to_local_unix(utc)) / SECONDS_PER_DAY)


## Minutes since local midnight at utc.
func local_minute_of_day(utc: int) -> int:
	return posmod(to_local_unix(utc), SECONDS_PER_DAY) / 60


## UTC instant of local midnight starting the given epoch day.
func utc_of_local_midnight(epoch_day: int) -> int:
	return to_utc_unix(epoch_day * SECONDS_PER_DAY)


func datetime_local(utc: int) -> Dictionary:
	var local := to_local_unix(utc)
	var d := Time.get_datetime_dict_from_unix_time(local)
	d["unix_utc"] = utc
	d["unix_local"] = local
	return d


## "YYYY-MM-DD" for an epoch day.
static func date_string(epoch_day: int) -> String:
	return Time.get_date_string_from_unix_time(epoch_day * SECONDS_PER_DAY)


## 0 = Sunday .. 6 = Saturday. 1970-01-01 was a Thursday.
static func weekday_of(epoch_day: int) -> int:
	return posmod(epoch_day + 4, 7)


# --- Test seams -------------------------------------------------------------

## Replaces the OS clock with a Callable returning UTC unix seconds (float).
## Pass an empty Callable to restore the OS clock. Clears any debug offset.
## Tests only.
func set_time_source(source: Callable) -> void:
	_time_source = source
	_anchor_real = _real_utc()
	_anchor_game = _anchor_real
	_cached_utc = _anchor_game
	_last_minute = _minute_of(_cached_utc)


## Forces a timezone bias in minutes, or null to use the system's. Tests only.
func set_time_zone_bias_override(minutes: Variant) -> void:
	_tz_bias_override = minutes


# --- Internals --------------------------------------------------------------

func _real_utc() -> float:
	if _time_source.is_valid():
		return float(_time_source.call())
	return Time.get_unix_time_from_system()


func _game_utc_at(real: float) -> float:
	return _anchor_game + (real - _anchor_real) * time_scale


func _rebase() -> void:
	var real := _real_utc()
	_anchor_game = _game_utc_at(real)
	_anchor_real = real


func _minute_of(utc: float) -> int:
	return floori(utc / 60.0)
