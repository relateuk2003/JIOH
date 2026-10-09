# tests/probe.gd — shared base for headless probe scenes, following OTIF's
# pattern: each probe prints PROBE OK / PROBE FAIL lines and quits non-zero
# on any failure.
# Run one:  godot --headless --path . res://tests/<Name>.tscn
# Run all:  tests/run_all.sh
class_name Probe
extends Node

const WED_2026_10_07 := 20733  # epoch day of a Wednesday
const SAT_2026_10_10 := 20736
const THU_2026_10_08 := 20734
const MON_2026_10_05 := 20731

var failures := 0
var fake_utc: float = 0.0


func check(cond: bool, what: String) -> void:
	if cond:
		print("PROBE OK: ", what)
	else:
		failures += 1
		print("PROBE FAIL: ", what)


func finish() -> void:
	print("%s: %s" % [name, "PASSED" if failures == 0 else "%d FAILED" % failures])
	WorldClock.set_time_source(Callable())
	WorldClock.set_time_zone_bias_override(null)
	get_tree().quit(1 if failures > 0 else 0)


## Puts the world on a controllable clock at local time on an epoch day.
## Clears any campaign and resyncs the phase machine.
func use_fake_clock(epoch_day: int, hour: int, minute: int, bias_minutes := 0) -> void:
	WorldClock.set_time_zone_bias_override(bias_minutes)
	WorldClock.time_scale = 1.0
	fake_utc = epoch_day * 86400 + hour * 3600 + minute * 60 - bias_minutes * 60
	WorldClock.set_time_source(func() -> float: return fake_utc)
	CampaignState.clear()
	DayPhase.resync()


## Advances the fake OS clock and polls, as a second of real play would.
func advance(seconds: float) -> void:
	fake_utc += seconds
	WorldClock.poll()


## Sets the fake clock to local hh:mm on the epoch day and polls.
func set_local(epoch_day: int, hour: int, minute: int) -> void:
	fake_utc = epoch_day * 86400 + hour * 3600 + minute * 60 - WorldClock.tz_bias_minutes() * 60
	WorldClock.poll()
