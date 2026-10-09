# scripts/props/dot_matrix_printer.gd — JIOH-27: the print room's dot matrix.
#
# A pacing device. Each blank takes 9 to 14 seconds of tractor feed and cannot
# be skipped, cancelled or hurried. It jams (more often as the ribbon wears),
# runs out of paper and, eventually, out of ribbon; a worn ribbon prints
# faint before it prints nothing. Jams are cleared by hand: lift the lid, pull
# the crumpled sheet, close the lid, turn the feed knob. The jammed sheet is
# gone and has to be printed again.
#
# It reports nothing. No light, no readout, no "low paper": the player looks
# in the tray, or does not. Refusals are physical (a clunk, a grind) and go
# out as signals for audio.
class_name DotMatrixPrinter
extends Node3D

signal printer_state_changed(from: State, to: State)
signal print_completed(instance_id: StringName)
signal printer_jam_cleared
## A physical refusal: what the machine did instead of printing.
signal print_refused(reason: StringName)

enum State { IDLE, PRINTING, JAMMED, OUT_OF_PAPER, OUT_OF_RIBBON }

## A full box. Authored to run dry around day 9 at a normal day's printing.
const PAPER_BOX := 100
## Ribbon worn per sheet. Faint from a quarter left, blank at none.
const RIBBON_WEAR := 1.0 / 220.0
const RIBBON_FAINT_BELOW := 0.25
const FAINTEST := 0.35
const PRINT_SECONDS := Vector2(9.0, 14.0)
const JAM_BASE := 0.04
const JAM_WORN_EXTRA := 0.12

## Builds a plain table under the printer for the blockout.
@export var with_stand := false
## QA seam: forces the jam roll (0 never, 1 always). Negative uses the seeded roll.
@export var jam_chance_override := -1.0

var state: State = State.IDLE
var lid_open := false
## What is lying in the output tray, if anything.
var output_stack: PaperStack = null
## The crumpled sheet under the lid while jammed.
var jam_sheet: Node3D = null

var lid: Interactable
var feed_knob: Interactable
var paper_tray: InsertReceiver
var _lid_hinge: Node3D
var _output_anchor: Node3D
var _job: Dictionary = {}


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	_build()
	InteractionManager.carry_changed.connect(_on_carry_changed)
	CampaignState.campaign_started.connect(restore_from_campaign)
	restore_from_campaign()


func _process(delta: float) -> void:
	if state != State.PRINTING:
		return
	_job.elapsed += delta
	if _job.jam_at >= 0.0 and _job.elapsed >= _job.jam_at:
		_jam()
	elif _job.elapsed >= _job.duration:
		_complete()


func paper_remaining() -> int:
	_ensure_state()
	return CampaignState.machines.paper_remaining


func ribbon_life() -> float:
	_ensure_state()
	return CampaignState.machines.ribbon_life


## Starts printing a blank. Returns false, with a physical refusal, when the
## machine cannot. There is deliberately no way to cancel or hurry a print.
func print_blank(doc_id: StringName) -> bool:
	_ensure_state()
	var m := CampaignState.machines
	if state == State.PRINTING or state == State.JAMMED:
		print_refused.emit(&"printer_busy" if state == State.PRINTING else &"printer_jammed")
		return false
	if lid_open:
		print_refused.emit(&"printer_lid_open")
		return false
	if m.paper_remaining <= 0:
		_set_state(State.OUT_OF_PAPER)
		print_refused.emit(&"printer_out_of_paper")
		return false
	if m.ribbon_life <= 0.0:
		_set_state(State.OUT_OF_RIBBON)
		print_refused.emit(&"printer_out_of_ribbon")
		return false
	# Seeded per campaign and per attempt, so a run is reproducible for QA.
	m.print_attempts += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([m.jam_seed, m.print_attempts])
	var duration := rng.randf_range(PRINT_SECONDS.x, PRINT_SECONDS.y)
	var chance: float = JAM_BASE + (1.0 - m.ribbon_life) * JAM_WORN_EXTRA
	if jam_chance_override >= 0.0:
		chance = jam_chance_override
	var jams := rng.randf() < chance
	_job = {
		"doc_id": doc_id, "duration": duration, "elapsed": 0.0,
		"jam_at": duration * rng.randf_range(0.3, 0.8) if jams else -1.0,
	}
	_set_state(State.PRINTING)
	return true


## Seconds the current print has left, or 0. For tests and audio, not UI.
func seconds_left() -> float:
	return maxf(_job.duration - _job.elapsed, 0.0) if state == State.PRINTING else 0.0


func restore_from_campaign() -> void:
	if not CampaignState.has_campaign():
		return
	_ensure_state()
	var m := CampaignState.machines
	# A print interrupted by quitting is simply lost; the paper was not used.
	state = (m.printer_state if m.printer_state != State.PRINTING else State.IDLE) as State
	lid_open = m.printer_lid_open
	_lid_hinge.rotation.x = deg_to_rad(-70.0) if lid_open else 0.0
	if jam_sheet:
		jam_sheet.free()
		jam_sheet = null
	if state == State.JAMMED and m.jam_stage == "stuck":
		_spawn_jam_sheet()
	if output_stack:
		output_stack.free()
		output_stack = null
	var waiting: Array[DocumentInstance] = []
	for doc in CampaignState.document_instances.values():
		if doc.location == CampaignState.Location.PRINTER_TRAY:
			waiting.append(doc)
	waiting.sort_custom(func(a, b): return a.printed_at_unix < b.printed_at_unix)
	for doc in waiting:
		_deliver(doc)


# --- Jams, lid, knob and tray -----------------------------------------------

func toggle_lid() -> void:
	lid_open = not lid_open
	CampaignState.machines.printer_lid_open = lid_open
	create_tween().tween_property(_lid_hinge, "rotation:x", deg_to_rad(-70.0) if lid_open else 0.0, 0.3)
	if jam_sheet:
		(jam_sheet.get_node("Interactable") as Interactable).set_targetable(lid_open)
	CampaignState.commit(&"printer_lid")


## The feed knob: after a jam has been pulled and the lid shut, a turn re-feeds
## and the printer is ready again. Otherwise it just advances nothing.
func turn_feed_knob() -> String:
	var m := CampaignState.machines
	if state != State.JAMMED:
		return ""
	if m.jam_stage == "stuck":
		return "printer_jam_still_in"
	if lid_open:
		return "printer_lid_open"
	m.jam_stage = ""
	_set_state(State.IDLE)
	printer_jam_cleared.emit()
	return ""


## The spare box goes into an empty tray.
func load_paper() -> void:
	CampaignState.machines.paper_remaining = PAPER_BOX
	if state == State.OUT_OF_PAPER:
		_set_state(State.IDLE)
	else:
		CampaignState.commit(&"paper_loaded")


func _jam() -> void:
	var m := CampaignState.machines
	m.paper_remaining -= 1
	m.ribbon_life = maxf(m.ribbon_life - RIBBON_WEAR, 0.0)
	m.jam_stage = "stuck"
	_job = {}
	_spawn_jam_sheet()
	_set_state(State.JAMMED)


func _complete() -> void:
	var m := CampaignState.machines
	var doc := DocumentRegistry.print_document(_job.doc_id)
	_job = {}
	m.paper_remaining -= 1
	var life: float = m.ribbon_life
	doc.print_quality = 1.0 if life >= RIBBON_FAINT_BELOW else lerpf(FAINTEST, 1.0, life / RIBBON_FAINT_BELOW)
	m.ribbon_life = maxf(life - RIBBON_WEAR, 0.0)
	doc.location = CampaignState.Location.PRINTER_TRAY
	CampaignState.add_document(doc)
	_deliver(doc)
	_set_state(State.IDLE)
	print_completed.emit(doc.instance_id)


func _deliver(doc: DocumentInstance) -> void:
	var docs: Array[DocumentInstance] = [doc]
	if output_stack:
		# Each new sheet lands face down on the last.
		var both := docs.duplicate()
		both.append_array(output_stack.documents)
		output_stack.documents.clear()
		output_stack.add(both)
		return
	output_stack = PaperStack.make(docs)
	output_stack.name = "Output"
	_output_anchor.add_child(output_stack)


func _spawn_jam_sheet() -> void:
	jam_sheet = Node3D.new()
	jam_sheet.name = "JamSheet"
	PropMesh.box(jam_sheet, "Crumple", Vector3(0, 0.015, 0), Vector3(0.12, 0.03, 0.08), Color(0.90, 0.89, 0.83))
	var it := PropMesh.handle(jam_sheet, JamSheetHandle.new(), "Interactable", Vector3(0, 0.02, 0), Vector3(0.14, 0.05, 0.1))
	(it as JamSheetHandle).printer = self
	add_child(jam_sheet)
	jam_sheet.position = Vector3(0, 0.13, -0.02)
	it.set_targetable(lid_open)


## Called when the crumpled sheet is pulled out of the mechanism.
func jam_sheet_pulled() -> void:
	CampaignState.machines.jam_stage = "pulled"
	jam_sheet = null
	CampaignState.commit(&"printer_jam_pulled")


func _set_state(next: State) -> void:
	var prev := state
	state = next
	CampaignState.machines.printer_state = next
	CampaignState.commit(&"printer")
	if prev != next:
		printer_state_changed.emit(prev, next)


# Taking the printed sheets off the tray puts them on the player's side.
func _on_carry_changed(item: Interactable) -> void:
	if output_stack and item == output_stack.interactable:
		for doc in output_stack.documents:
			doc.location = CampaignState.Location.DESK
		output_stack = null
		CampaignState.commit(&"printout_taken")


func _ensure_state() -> void:
	var m := CampaignState.machines
	if not m.has("paper_remaining"):
		m.paper_remaining = PAPER_BOX
		m.ribbon_life = 1.0
		m.printer_state = State.IDLE
		m.printer_lid_open = false
		m.jam_stage = ""
		m.jam_seed = hash([CampaignState.campaign_start_utc, "printer"])
		m.print_attempts = 0


func _build() -> void:
	var beige := Color(0.80, 0.77, 0.68)
	var dark := Color(0.25, 0.24, 0.22)
	if with_stand:
		# The stand is level geometry; the machine sits on top of it.
		var stand := StaticBody3D.new()
		stand.name = "Stand"
		stand.collision_layer = 1
		stand.top_level = false
		add_child(stand)
		stand.position = Vector3(0, -0.375, 0.05)
		PropMesh.box(stand, "Table", Vector3.ZERO, Vector3(1.0, 0.75, 0.9), Color(0.45, 0.40, 0.33))
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(1.0, 0.75, 0.9)
		stand.add_child(shape)
	PropMesh.box(self, "Body", Vector3(0, 0.06, 0), Vector3(0.48, 0.12, 0.34), beige)
	PropMesh.box(self, "Platen", Vector3(0, 0.125, -0.02), Vector3(0.40, 0.02, 0.06), dark)
	_lid_hinge = Node3D.new()
	_lid_hinge.name = "LidHinge"
	_lid_hinge.position = Vector3(0, 0.12, -0.1)
	add_child(_lid_hinge)
	PropMesh.box(_lid_hinge, "Lid", Vector3(0, 0.01, 0.12), Vector3(0.46, 0.02, 0.24), beige.darkened(0.08))
	lid = PropMesh.handle(_lid_hinge, PrinterPart.new(), "LidInteractable", Vector3(0, 0.02, 0.12), Vector3(0.46, 0.05, 0.24))
	lid.object_id = &"printer_lid"
	lid.display_name = "Printer lid"
	(lid as PrinterPart).printer = self
	(lid as PrinterPart).part = &"lid"
	PropMesh.box(self, "FeedKnob", Vector3(0.26, 0.08, 0), Vector3(0.03, 0.05, 0.05), dark)
	feed_knob = PropMesh.handle(self, PrinterPart.new(), "FeedKnobInteractable", Vector3(0.27, 0.08, 0), Vector3(0.05, 0.07, 0.07))
	feed_knob.object_id = &"printer_feed_knob"
	feed_knob.display_name = "Feed knob"
	(feed_knob as PrinterPart).printer = self
	(feed_knob as PrinterPart).part = &"knob"
	# Fanfold paper sits in a tray under the back of the machine.
	PropMesh.box(self, "PaperTray", Vector3(0, 0.02, -0.26), Vector3(0.40, 0.04, 0.16), dark)
	paper_tray = PropMesh.handle(self, PrinterTray.new(), "PaperTrayInteractable", Vector3(0, 0.04, -0.26), Vector3(0.42, 0.08, 0.18)) as InsertReceiver
	paper_tray.object_id = &"printer_paper_tray"
	paper_tray.display_name = "Paper tray"
	(paper_tray as PrinterTray).printer = self
	_output_anchor = Node3D.new()
	_output_anchor.name = "OutputTray"
	_output_anchor.position = Vector3(0, 0.0, 0.32)
	add_child(_output_anchor)
	PropMesh.box(_output_anchor, "TrayBoard", Vector3(0, -0.005, 0), Vector3(0.30, 0.01, 0.32), dark)
