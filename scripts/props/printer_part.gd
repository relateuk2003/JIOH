# scripts/props/printer_part.gd — JIOH-27: the printer's lid and feed knob.
class_name PrinterPart
extends Interactable

var printer: DotMatrixPrinter
var part: StringName = &""


func _init() -> void:
	verbs = Verb.OPEN


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base != "":
		return base
	if part == &"lid" and printer.state == DotMatrixPrinter.State.PRINTING:
		return "printer_busy"
	if part == &"knob":
		var m := CampaignState.machines
		if printer.state == DotMatrixPrinter.State.JAMMED and m.get("jam_stage") == "stuck":
			return "printer_jam_still_in"
		if printer.state == DotMatrixPrinter.State.JAMMED and printer.lid_open:
			return "printer_lid_open"
	return ""


func interact(verb: Verb, _payload: Variant = null) -> void:
	if verb != Verb.OPEN:
		return
	if part == &"lid":
		printer.toggle_lid()
	else:
		printer.turn_feed_knob()
