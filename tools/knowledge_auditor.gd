# tools/knowledge_auditor.gd — JIOH-26: runs KnowledgeAuditor over every
# authored day and fails the build if any required field is unanswerable.
#
#   godot --headless --path . res://tools/knowledge_auditor.tscn [-- --verbose]
extends Node


func _ready() -> void:
	var matrix: PackMatrix = load("res://resources/documents/pack_matrix.tres")
	var a := KnowledgeAuditor.run(InformationBoard.days, matrix,
		DocumentRegistry.has_template, DocumentRegistry.get_template)
	if "--verbose" in OS.get_cmdline_user_args():
		for line in a.report:
			print(line)
	for f in a.failures:
		print("knowledge_auditor: FAIL ", f)
	print("knowledge_auditor: %d days, %d looked-up fields, %s" % [InformationBoard.days.size(),
		a.report.size(), "OK" if a.passed() else "%d FAILED" % a.failures.size()])
	get_tree().quit(0 if a.passed() else 1)
