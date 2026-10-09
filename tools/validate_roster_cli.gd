# tools/validate_roster_cli.gd — JIOH-21: the roster checks for run_all.sh.
extends Node


func _ready() -> void:
	var roster := TradeRoster.shipped()
	var problems := RosterValidator.problems(roster, load("res://resources/documents/pack_matrix.tres"))
	for p in problems:
		print("validate_roster: FAIL ", p)
	print("validate_roster: %d trades, %s" % [roster.trades.size() if roster else 0, "OK" if problems.is_empty() else "%d problems" % problems.size()])
	get_tree().quit(0 if problems.is_empty() else 1)
