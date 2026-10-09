# scripts/props/desk_drawer.gd — JIOH-57: the drawer in the front of your
# desk. It slides out toward you; paper put in it stays in it, across days
# and across a quit, until you take it out again.
#
# Built facing local +Z (toward the chair); the level turns it to face the
# player's side of the desk.
class_name DeskDrawer
extends Node3D

const WIDTH := 0.42
const DEPTH := 0.45
const PULL := 0.28

var tray: Node3D
var contents: Node3D
var handle: Openable
var receiver: DrawerTray


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	tray = Node3D.new()
	tray.name = "Tray"
	add_child(tray)
	var wood := Color(0.36, 0.3, 0.24)
	PropMesh.box(tray, "Front", Vector3(0, 0, 0.01), Vector3(WIDTH, 0.11, 0.02), wood)
	PropMesh.box(tray, "Pull", Vector3(0, 0.02, 0.025), Vector3(0.1, 0.012, 0.012), Color(0.6, 0.6, 0.62))
	PropMesh.box(tray, "Floor", Vector3(0, -0.048, -DEPTH / 2.0), Vector3(WIDTH - 0.02, 0.008, DEPTH), wood.darkened(0.2))
	for side in [-1, 1]:
		PropMesh.box(tray, "Side", Vector3(side * (WIDTH / 2.0 - 0.015), -0.015, -DEPTH / 2.0), Vector3(0.01, 0.07, DEPTH), wood)
	PropMesh.box(tray, "Back", Vector3(0, -0.015, -DEPTH), Vector3(WIDTH - 0.02, 0.07, 0.01), wood)
	contents = Node3D.new()
	contents.name = "Contents"
	contents.position = Vector3(0, -0.044, -0.2)
	tray.add_child(contents)
	handle = Openable.new()
	handle.hinge = tray
	handle.open_rotation_degrees = Vector3.ZERO
	handle.open_offset = Vector3(0, 0, PULL)
	handle.object_id = &"desk_drawer"
	handle.display_name = "Drawer"
	PropMesh.handle(tray, handle, "Interactable", Vector3(0, 0, 0.015), Vector3(WIDTH, 0.11, 0.03))
	handle.opened_changed.connect(_on_opened)
	receiver = DrawerTray.new()
	receiver.drawer = self
	receiver.contents = contents
	# Flat on the floor of the tray, under anything lying in it.
	PropMesh.handle(tray, receiver, "TrayInterior", Vector3(0, -0.042, -0.2), Vector3(WIDTH - 0.06, 0.004, 0.36))
	InteractionManager.inserted.connect(_on_inserted)
	_on_opened(false)


func is_open() -> bool:
	return handle.is_open


func stacks() -> Array[PaperStack]:
	var out: Array[PaperStack] = []
	for c in contents.get_children():
		if c is PaperStack and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Lays a stack in the tray, keeping it there through days and reloads.
func put(s: PaperStack) -> void:
	if s.get_parent():
		s.reparent(contents, false)
	else:
		contents.add_child(s)
	s.transform = Transform3D(Basis(), Vector3(0, 0.003 * (stacks().size() - 1), 0))
	s.visible = true
	s.interactable.set_targetable(is_open())
	_keep(s)


func _keep(s: PaperStack) -> void:
	for d in s.documents:
		d.location = CampaignState.Location.DRAWER
		CampaignState.add_document(d)
	CampaignState.commit(&"drawer", true)


func _on_opened(open: bool) -> void:
	receiver.set_targetable(open)
	for s in stacks():
		s.interactable.set_targetable(open)


## Paper laid onto a stack already in the drawer joins it there.
func _on_inserted(_item: Interactable, into: InsertReceiver) -> void:
	if into is PaperStackHandle and (into as PaperStackHandle).stack().get_parent() == contents:
		_keep((into as PaperStackHandle).stack())


## The drawer's paper comes back as one pile, oldest at the bottom.
func restore_from_campaign() -> void:
	for s in stacks():
		s.free()
	var docs: Array[DocumentInstance] = []
	for d in CampaignState.document_instances.values():
		if d.location == CampaignState.Location.DRAWER:
			docs.append(d)
	if docs.is_empty():
		return
	docs.sort_custom(func(a, b): return a.printed_at_unix < b.printed_at_unix \
		or (a.printed_at_unix == b.printed_at_unix and String(a.instance_id) < String(b.instance_id)))
	var s := PaperStack.make(docs)
	contents.add_child(s)
	s.interactable.set_targetable(is_open())
