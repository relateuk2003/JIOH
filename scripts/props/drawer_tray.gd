# scripts/props/drawer_tray.gd — JIOH-57: the inside of the desk drawer, as
# somewhere paper can be put.
class_name DrawerTray
extends InsertReceiver

var drawer: DeskDrawer


func _init() -> void:
	verbs = Verb.INSERT
	accepted_tags = [&"paper_stack"]
	consume = false
	object_id = &"desk_drawer_tray"
	display_name = "Drawer"


func interact(verb: Verb, payload: Variant = null) -> void:
	if verb != Verb.INSERT:
		return
	var item := payload as Interactable
	received.emit(item)
	drawer.put(item.body() as PaperStack)
