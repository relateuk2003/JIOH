# scripts/props/date_stamp.gd — JIOH-27: the rubber wheel date stamp.
#
# It does not follow WorldClock. It prints whatever its three bands were last
# wound to, which on day one is a date from before Janice left. Nothing on it
# or anywhere else reports that it is wrong; the player reads it by looking at
# the bands, or does not.
#
# Winding: target a band on the stamp where it stands and press use; each
# press turns that band one detent forward, with a ratchet that will not take
# another turn until the last has clicked home. Advancing a week takes a few
# real seconds. There is no "set to today".
#
# Stamping: carry the stamp and press it onto a stack. The top sheet gets the
# wheel's date in ink that fades with every impression until the stamp is
# pressed on the ink pad again; the sheet then slides under the stack so the
# next press stamps the next sheet.
class_name DateStamp
extends Node3D

signal document_stamped(instance_id: StringName, stamped_date: String)
signal band_turned(band: StringName, value: int)

enum Band { DAY, MONTH, YEAR }

const STAMP_ID := &"received"
## Days before day one the wheels are left on.
const LEFT_BEHIND_DAYS := 6
const DETENT_SECONDS := 0.45
const INK_PER_IMPRESSION := 0.07
const INK_FLOOR := 0.12
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const YEAR_FIRST := 2020
const YEAR_COUNT := 10

var handle: Interactable
var bands: Array[StampBand] = []
var _labels: Array[Label3D] = []
var _ratchet := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"campaign_restorable")
	_build()
	InteractionManager.carry_changed.connect(_on_carry_changed)
	CampaignState.campaign_started.connect(restore_from_campaign)
	restore_from_campaign()


func _process(delta: float) -> void:
	_ratchet = maxf(_ratchet - delta, 0.0)


## The wheel as {day, month, year}.
func wheel() -> Dictionary:
	_ensure_state()
	return CampaignState.machines.stamp_wheel


## What the next impression will read, as "YYYY-MM-DD". Impossible dates
## (31 FEB) print as they stand: the bands do not know about months.
func wheel_date() -> String:
	var w := wheel()
	return "%04d-%02d-%02d" % [w.year, w.month, w.day]


func ink() -> float:
	_ensure_state()
	return CampaignState.machines.stamp_ink


func is_ratchet_free() -> bool:
	return _ratchet <= 0.0


## Turns one band one detent forward. Returns false while the ratchet is
## still clicking home from the last turn.
func wind(band: Band) -> bool:
	if _ratchet > 0.0:
		return false
	_ratchet = DETENT_SECONDS
	var w := wheel()
	match band:
		Band.DAY: w.day = w.day % 31 + 1
		Band.MONTH: w.month = w.month % 12 + 1
		Band.YEAR: w.year = YEAR_FIRST + (w.year - YEAR_FIRST + 1) % YEAR_COUNT
	_refresh_labels()
	CampaignState.commit(&"stamp_wound")
	var key: StringName = [&"day", &"month", &"year"][band]
	band_turned.emit(key, w[key])
	return true


## Presses the stamp onto the top sheet of a stack.
func stamp_onto(stack: PaperStack) -> void:
	var doc := stack.top()
	if doc == null:
		return
	doc.apply_stamp(STAMP_ID, wheel_date())
	doc.stamp.ink_alpha = ink()
	doc.stamp.position = Vector2(0.74 + _rng.randf_range(-0.04, 0.04), 0.09 + _rng.randf_range(-0.03, 0.03))
	doc.stamp.rotation_degrees = _rng.randf_range(-7.0, 7.0)
	CampaignState.machines.stamp_ink = maxf(ink() - INK_PER_IMPRESSION, INK_FLOOR)
	CampaignState.add_document(doc)
	stack.turn_top_under()
	CampaignState.commit(&"stamped")
	document_stamped.emit(doc.instance_id, doc.stamp.stamped_date)


## Pressed on the pad: full ink again.
func re_ink() -> void:
	_ensure_state()
	CampaignState.machines.stamp_ink = 1.0
	CampaignState.commit(&"stamp_inked")


func restore_from_campaign() -> void:
	_refresh_labels()


## Defaults appear the first time the stamp meets a campaign: the wheels on a
## date from before Janice left, a freshly inked pad.
func _ensure_state() -> void:
	var m := CampaignState.machines
	if not m.has("stamp_wheel"):
		var iso := WorldClock.date_string(CampaignState.campaign_start_epoch_day - LEFT_BEHIND_DAYS)
		m.stamp_wheel = {"year": int(iso.substr(0, 4)), "month": int(iso.substr(5, 2)), "day": int(iso.substr(8, 2))}
	if not m.has("stamp_ink"):
		m.stamp_ink = 1.0


func _refresh_labels() -> void:
	if _labels.is_empty() or not CampaignState.has_campaign():
		return
	var w := wheel()
	_labels[Band.DAY].text = "%02d" % w.day
	_labels[Band.MONTH].text = MONTHS[w.month - 1]
	_labels[Band.YEAR].text = "%02d" % (w.year % 100)


# Bands go untargetable while the stamp is in hand, with the stamp itself.
func _on_carry_changed(item: Interactable) -> void:
	for b in bands:
		b.set_targetable(item != handle)


func _build() -> void:
	var black := Color(0.09, 0.09, 0.10)
	PropMesh.box(self, "Base", Vector3(0, 0.02, 0), Vector3(0.07, 0.04, 0.045), black)
	PropMesh.box(self, "Frame", Vector3(0, 0.065, 0), Vector3(0.075, 0.05, 0.012), black)
	PropMesh.box(self, "Handle", Vector3(0, 0.12, 0), Vector3(0.03, 0.06, 0.03), Color(0.35, 0.18, 0.10))
	handle = PropMesh.handle(self, Interactable.new(), "Interactable", Vector3(0, 0.09, 0), Vector3(0.08, 0.13, 0.06))
	handle.verbs = Interactable.Verb.PICK_UP | Interactable.Verb.EXAMINE
	handle.tags = [&"date_stamp"]
	handle.display_name = "Date stamp"
	# The three rubber bands, read through the frame: day, month, year.
	for i in 3:
		var x := -0.022 + i * 0.022
		PropMesh.box(self, "Wheel_%d" % i, Vector3(x, 0.065, 0.008), Vector3(0.018, 0.03, 0.012), Color(0.55, 0.52, 0.47))
		_labels.append(PropMesh.label(self, "BandLabel_%d" % i, "", Vector3(x, 0.065, 0.0145), 22))
		var band := StampBand.new()
		band.stamp = self
		band.band = i
		band.object_id = StringName("date_stamp_band_%s" % ["day", "month", "year"][i])
		band.display_name = ["Day band", "Month band", "Year band"][i]
		PropMesh.handle(self, band, "Band_%d" % i, Vector3(x, 0.065, 0.02), Vector3(0.02, 0.03, 0.02))
		bands.append(band)
