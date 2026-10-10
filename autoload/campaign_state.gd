# autoload/campaign_state.gd — the fortnight laid over the player's real
# calendar (JIOH-15), and the one owner of the save file (JIOH-36).
#
# New Game stamps today's date and generates fourteen consecutive days from
# it, flagged working or weekend by weekday. The campaign day is always a date
# difference from the stamp, never a stored counter, so it cannot drift.
#
# Saving is autosave only. There is no public save(): systems call
# commit(reason) whenever something meaningful changes, writes are debounced
# to one per 750 ms with a trailing write, and every write is atomic (temp
# file, flush, rename). No other script writes to disk.
extends Node

signal campaign_started
signal committed(reason: StringName)
## The game is about to close: anything held in hand-written limbo (a box
## half typed) writes itself into the campaign now, before the last save.
signal closing

const CAMPAIGN_LENGTH := 14
const SCHEMA_VERSION := 1
const DEBOUNCE_SECONDS := 0.75

## Where a document physically is (JIOH-36).
## Append only: the values are saved as integers.
enum Location { IN_TRAY, OUT_TRAY, DESK, CLIPBOARD, FILED, HANDED_OVER, LOST, LODGED, PRINTER_TRAY, DRAWER }

var slot: int = 1
var campaign_start_utc: int = 0
## Local epoch day of the stamp. Kept alongside the UTC instant so a later
## timezone change does not move day 1.
var campaign_start_epoch_day: int = 0
var campaign_start_tz_bias: int = 0
## Seeds every per-day draw (arrivals, read jitter). Drawn once at New Game
## and saved, so a replayed morning matches the one that was missed.
var campaign_seed: int = 0
var campaign_days: Array[CampaignDay] = []

# The rest of the save schema (JIOH-36). Every key is present in every save.
var clock_witness: Dictionary = {}
## Fourteen entries, allocated at the stamp. Never appended to or removed from.
var day_records: Array[Dictionary] = []
## Instance UUID -> DocumentInstance.
var document_instances: Dictionary = {}
var world_artefacts: Array = []
## Every post into and retrieval from a pigeon hole, in order (JIOH-32).
## Appended to, never edited: second thoughts stay on the record.
var lodgement_log: Array[Dictionary] = []
## persistent_id -> object record, owned by ObjectRegistry (JIOH-54).
var world_objects: Dictionary = {}
var relationships: Dictionary = {}
# trade_id -> RelationshipState handed out by get_relationship(); folded back
# into relationships whenever the campaign is serialised.
var _relationship_states: Dictionary = {}
## Office machine state that is not a transform (JIOH-27): the stamp's wheel
## and ink, paper and ribbon, the printer's state and jam seed. Each machine
## owns its keys and fills in its defaults the first time it sees a campaign.
var machines: Dictionary = {}
var story_flags: Dictionary = {}
## FMV clips seen, id -> unix time first started (JIOH-52). A seen clip is
## skippable ever after.
var fmv_viewed: Dictionary = {}
var settings: Dictionary = {}
var last_write_utc: int = 0

var _pending := false
var _since_write := DEBOUNCE_SECONDS


func _process(delta: float) -> void:
	_since_write += delta
	if _pending and _since_write >= DEBOUNCE_SECONDS:
		_write_to_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and has_campaign():
		closing.emit()
		commit(&"close", true)


func has_campaign() -> bool:
	return campaign_start_utc != 0


## Stamps a new campaign at the current WorldClock time and writes the first
## save.
func new_campaign() -> void:
	clear()
	campaign_start_utc = WorldClock.now_unix()
	campaign_start_epoch_day = WorldClock.local_epoch_day(campaign_start_utc)
	campaign_start_tz_bias = WorldClock.tz_bias_minutes()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	campaign_seed = rng.randi()
	generate_calendar(campaign_start_epoch_day)
	for i in CAMPAIGN_LENGTH:
		day_records.append(_new_day_record())
	campaign_started.emit()


func clear() -> void:
	campaign_start_utc = 0
	campaign_start_epoch_day = 0
	campaign_start_tz_bias = 0
	campaign_seed = 0
	campaign_days.clear()
	clock_witness = {}
	day_records.clear()
	document_instances = {}
	world_artefacts = []
	lodgement_log.clear()
	world_objects = {}
	relationships = {}
	_relationship_states = {}
	machines = {}
	story_flags = {}
	fmv_viewed = {}
	settings = {}
	last_write_utc = 0
	_pending = false


## Fourteen consecutive dates from start_epoch_day. Bank holidays are ignored
## on purpose: the office does not observe them.
func generate_calendar(start_epoch_day: int) -> void:
	campaign_days.clear()
	var ordinal := 0
	for i in CAMPAIGN_LENGTH:
		var day := CampaignDay.new()
		day.index = i + 1
		day.epoch_day = start_epoch_day + i
		day.date = WorldClock.date_string(day.epoch_day)
		var weekday := WorldClock.weekday_of(day.epoch_day)
		day.is_working_day = weekday != 0 and weekday != 6
		if day.is_working_day:
			ordinal += 1
			day.working_day_ordinal = ordinal
		campaign_days.append(day)


## Campaign day at a UTC instant: 0 before the start (or with no campaign),
## 1..14 during, and above 14 once the fortnight has concluded.
func campaign_day_for(utc: int) -> int:
	if not has_campaign():
		return 0
	var d := WorldClock.local_epoch_day(utc) - campaign_start_epoch_day + 1
	return d if d >= 1 else 0


func get_day(index: int) -> CampaignDay:
	if index < 1 or index > campaign_days.size():
		return null
	return campaign_days[index - 1]


func is_working_day_at(utc: int) -> bool:
	var day := get_day(campaign_day_for(utc))
	return day != null and day.is_working_day


func is_concluded() -> bool:
	return has_campaign() and WorldClock.get_campaign_day() > CAMPAIGN_LENGTH


## The calendar day carrying a working-day ordinal (1..10), or null.
func day_for_working_ordinal(ordinal: int) -> CampaignDay:
	for day in campaign_days:
		if day.working_day_ordinal == ordinal:
			return day
	return null


## Today's record in day_records, or an empty dictionary outside the fortnight.
func today_record() -> Dictionary:
	var day := WorldClock.get_campaign_day()
	return day_records[day - 1] if day >= 1 and day <= day_records.size() else {}


func has_viewed_fmv(id: StringName) -> bool:
	return fmv_viewed.has(String(id))


## Recorded as the clip starts, so a crash mid-way never means watching it
## through again.
func mark_fmv_viewed(id: StringName) -> void:
	if not has_viewed_fmv(id):
		fmv_viewed[String(id)] = WorldClock.now_unix()
		commit(&"fmv", true)


func add_document(doc: DocumentInstance) -> void:
	document_instances[doc.instance_id] = doc


# --- Autosave ------------------------------------------------------------------

## Records that something meaningful changed. Writes at most once per
## debounce window, with a trailing write guaranteed. immediate bypasses the
## debounce (phase boundaries, quitting).
func commit(reason: StringName, immediate := false) -> void:
	if not has_campaign():
		return
	_pending = true
	if immediate or _since_write >= DEBOUNCE_SECONDS:
		_write_to_disk()
	committed.emit(reason)


## Loads the slot's save if there is one. Returns false if there is none.
func resume() -> bool:
	var path := save_path()
	if not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		push_error("CampaignState: %s is not a save" % path)
		return false
	from_dict(data)
	return has_campaign()


func save_dir() -> String:
	return "user://saves/slot_%d" % slot


func save_path() -> String:
	return save_dir().path_join("campaign.sav")


func _write_to_disk() -> void:
	_pending = false
	_since_write = 0.0
	last_write_utc = WorldClock.now_unix()
	DirAccess.make_dir_recursive_absolute(save_dir())
	var path := save_path()
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("CampaignState: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	file.store_buffer(var_to_bytes(to_dict()))
	file.flush()
	file.close()
	# The rename is the only operation that makes a new save visible.
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("CampaignState: rename to %s failed (%s)" % [path, error_string(err)])


# --- Serialisation ---------------------------------------------------------------

## The campaign's standing with a trade (JIOH-21). Created at defaults on
## first request; never null. Mutate the returned object and commit().
func get_relationship(trade_id: StringName) -> RelationshipState:
	var key := String(trade_id)
	if not _relationship_states.has(key):
		var raw: Variant = relationships.get(key)
		_relationship_states[key] = RelationshipState.from_dict(raw if raw is Dictionary else {})
	return _relationship_states[key]


func _relationships_dict() -> Dictionary:
	var out := relationships.duplicate(true)
	for key in _relationship_states:
		out[key] = (_relationship_states[key] as RelationshipState).to_dict()
	return out


func to_dict() -> Dictionary:
	var docs := {}
	for id in document_instances:
		docs[String(id)] = (document_instances[id] as DocumentInstance).to_dict()
	var days := []
	for day in campaign_days:
		days.append({
			"scheduled_trades": day.scheduled_trades.map(func(t): return String(t)),
			"story_beat_id": String(day.story_beat_id),
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"campaign_start_utc": campaign_start_utc,
		"campaign_start_epoch_day": campaign_start_epoch_day,
		"campaign_start_tz_bias": campaign_start_tz_bias,
		"campaign_seed": campaign_seed,
		"clock_witness": clock_witness.duplicate(true),
		"current_day": campaign_day_for(WorldClock.now_unix()),
		"calendar": days,
		"day_records": day_records.duplicate(true),
		"document_instances": docs,
		"world_artefacts": world_artefacts.duplicate(true),
		"lodgement_log": lodgement_log.duplicate(true),
		"world_objects": world_objects.duplicate(true),
		"relationships": _relationships_dict(),
		"machines": machines.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"fmv_viewed": fmv_viewed.duplicate(true),
		"settings": settings.duplicate(true),
		"last_write_utc": last_write_utc,
		"written_by_build": BuildInfo.version,
	}


func from_dict(d: Dictionary) -> void:
	clear()
	campaign_start_utc = int(d.get("campaign_start_utc", 0))
	if not has_campaign():
		return
	campaign_start_epoch_day = int(d.get("campaign_start_epoch_day", 0))
	campaign_start_tz_bias = int(d.get("campaign_start_tz_bias", 0))
	campaign_seed = int(d.get("campaign_seed", 0))
	generate_calendar(campaign_start_epoch_day)
	var days: Array = d.get("calendar", [])
	for i in mini(days.size(), campaign_days.size()):
		var src: Dictionary = days[i]
		var trades: Array[StringName] = []
		for t in src.get("scheduled_trades", []):
			trades.append(StringName(t))
		campaign_days[i].scheduled_trades = trades
		campaign_days[i].story_beat_id = StringName(src.get("story_beat_id", ""))
	clock_witness = d.get("clock_witness", {}).duplicate(true)
	for record in d.get("day_records", []):
		day_records.append((record as Dictionary).duplicate(true))
	for id in d.get("document_instances", {}):
		var doc := DocumentInstance.from_dict(d.document_instances[id])
		if doc:
			document_instances[doc.instance_id] = doc
	world_artefacts = d.get("world_artefacts", []).duplicate(true)
	for entry in d.get("lodgement_log", []):
		lodgement_log.append((entry as Dictionary).duplicate(true))
	world_objects = d.get("world_objects", {}).duplicate(true)
	relationships = d.get("relationships", {}).duplicate(true)
	machines = d.get("machines", {}).duplicate(true)
	story_flags = d.get("story_flags", {}).duplicate(true)
	fmv_viewed = d.get("fmv_viewed", {}).duplicate(true)
	settings = d.get("settings", {}).duplicate(true)
	last_write_utc = int(d.get("last_write_utc", 0))


func _new_day_record() -> Dictionary:
	return {
		"phase_outcomes": {},
		"packs_prepared": 0,
		"packs_collected": 0,
		"packs_failed": 0,
		"lodgements_made": 0,
		"attended": false,
		"minutes_played": 0,
		# trade_id -> "arrived" | "served" | "no_handout" | "no_show" (JIOH-28)
		"hatch": {},
		# Set once every arrival that day has an outcome; replay skips it.
		"hatch_settled": false,
	}
