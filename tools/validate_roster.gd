# tools/validate_roster.gd — JIOH-21: run from the editor (File > Run) to
# check the roster. CI runs the same checks via tools/validate_roster_cli.tscn.
@tool
extends EditorScript


func _run() -> void:
	var problems := RosterValidator.problems(TradeRoster.shipped(), load("res://resources/documents/pack_matrix.tres"))
	for p in problems:
		push_error("validate_roster: " + p)
	print("validate_roster: %s" % ("OK" if problems.is_empty() else "%d problems" % problems.size()))
