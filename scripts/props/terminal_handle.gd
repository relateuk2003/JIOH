# scripts/props/terminal_handle.gd — JIOH-26: sit down at the terminal.
class_name TerminalHandle
extends Interactable

var terminal: CrtTerminal


func _init() -> void:
	verbs = Verb.OPEN


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base == "" and InteractionManager.carried_item != null:
		return "hands_full"
	return base


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb == Verb.OPEN and not terminal.active:
		terminal.begin_session()
