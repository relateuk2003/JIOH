# autoload/build_info.gd — JIOH-60: which build this is, readable anywhere.
#
# The version is baked by build/build.sh from git describe, so a save, a
# telemetry payload or a crash report can always say which build wrote it.
# Shown in the corner of the pause screen.
extends Node

const PATH := "res://resources/build_info.tres"

var version := "dev"
var channel := "dev"


func _ready() -> void:
	var stamp := load(PATH) as BuildStamp
	if stamp:
		version = stamp.version
		channel = stamp.channel
	# `janice -- --print-build` answers support and the build tests.
	if "--print-build" in OS.get_cmdline_user_args():
		print("JANICE BUILD %s %s" % [version, channel])
		get_tree().quit()


## What the pause screen prints, and what reports carry.
func label() -> String:
	match channel:
		"release":
			return "v%s" % version
		"dev":
			return "dev build"
	return "v%s (%s)" % [version, channel]


## Merged into every telemetry payload and crash report.
func stamp(payload: Dictionary) -> Dictionary:
	payload["build_version"] = version
	payload["build_channel"] = channel
	return payload
