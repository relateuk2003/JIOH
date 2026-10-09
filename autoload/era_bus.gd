# autoload/era_bus.gd — JIOH-66: the era character, applied once.
#
# Every sound reaches Master through Era: Master <- EraOut <- Era <-
# {Ambience, Mechanical, Voice, Interface, FMV, the three Space reverbs}.
# Era low-passes at the 22 kHz Nyquist ceiling and then crushes to the
# profile's bit depth (BitCrushEffect); EraOut's hard limiter catches what
# the crusher adds. Only the debug Monitor bus skips all this.
#
# The bus layout file is never edited at runtime: the tuning comes from
# era_profile.tres and is applied here at launch. set_bypass() switches the
# chain off and on for A/B listening, live.
extends Node

const PROFILE := "res://resources/audio/era_profile.tres"
## Buses a sound may be played on. Anything else is rerouted.
const SOURCES: Array[StringName] = [&"Ambience", &"Mechanical", &"Voice", &"Interface", &"FMV",
	&"Space_small", &"Space_hall", &"Space_dead"]
## Physics layer the acoustic zones sit on, away from the interaction ray.
const ZONE_LAYER := 1 << 9

var profile: EraProfile
var bypassed := false


func _ready() -> void:
	profile = load(PROFILE) as EraProfile
	apply_profile()
	get_tree().node_added.connect(_on_node_added)


func apply_profile() -> void:
	var era := AudioServer.get_bus_index(&"Era")
	var out := AudioServer.get_bus_index(&"EraOut")
	if era < 0 or out < 0:
		push_error("EraBus: the Era buses are missing from the bus layout")
		return
	var lp := AudioServer.get_bus_effect(era, 0) as AudioEffectLowPassFilter
	lp.cutoff_hz = profile.lowpass_hz
	lp.resonance = profile.lowpass_resonance
	BitCrushEffect.configure(AudioServer.get_bus_effect(era, 1) as AudioEffectDistortion, profile.bit_depth)
	# AudioEffectHardLimiter: Godot 4's replacement for the deprecated
	# AudioEffectLimiter, and unity gain below the ceiling.
	var lim := AudioServer.get_bus_effect(out, 0) as AudioEffectHardLimiter
	lim.ceiling_db = profile.limiter_ceiling_db
	lim.release = profile.limiter_release
	set_bypass(bypassed)


## Clean, full band, no crush, no limiter; and back, without a restart.
func set_bypass(on: bool) -> void:
	bypassed = on
	AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index(&"Era"), on)
	AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index(&"EraOut"), on)


## Nothing plays straight to Master: a player left on it (or on a bus that
## does not exist) is put on Mechanical, with a warning in debug builds.
func _on_node_added(n: Node) -> void:
	if not (n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D):
		return
	if n is AudioStreamPlayer3D:
		(n as AudioStreamPlayer3D).area_mask |= ZONE_LAYER
	var bus: StringName = n.get(&"bus")
	if bus in SOURCES:
		return
	if OS.is_debug_build():
		push_warning("EraBus: %s played on '%s'; routed through Mechanical" % [n.get_path(), bus])
	n.set(&"bus", &"Mechanical")


## The buses a source passes through on its way to Master.
static func route(bus: StringName) -> PackedStringArray:
	var path := PackedStringArray()
	var i := AudioServer.get_bus_index(bus)
	while i >= 0 and path.size() < 16:
		path.append(AudioServer.get_bus_name(i))
		if i == 0:
			break
		i = AudioServer.get_bus_index(AudioServer.get_bus_send(i))
	return path
