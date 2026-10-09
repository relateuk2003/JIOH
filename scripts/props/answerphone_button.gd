# scripts/props/answerphone_button.gd — JIOH-26: play, stop or rewind.
class_name AnswerphoneButton
extends Interactable

var machine: Answerphone
var action: StringName = &"play"


func _init() -> void:
	verbs = Verb.OPEN


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb != Verb.OPEN:
		return
	match action:
		&"play": machine.play()
		&"stop": machine.stop()
		&"rewind": machine.rewind()
