# scripts/props/printer_tray.gd — JIOH-27: takes the spare box of fanfold
# paper, but only once the tray has run empty.
class_name PrinterTray
extends InsertReceiver

var printer: DotMatrixPrinter


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"paper_box"]
	consume = true


func can_interact(verb: Verb, payload: Variant = null) -> String:
	var base := super(verb, payload)
	if base == "" and printer.paper_remaining() > 0:
		return "printer_tray_not_empty"
	return base


func interact(verb: Verb, payload: Variant = null) -> void:
	super(verb, payload)
	if verb == Verb.INSERT:
		printer.load_paper()
