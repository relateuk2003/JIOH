# tests/SaveProbe.gd — JIOH-36 acceptance criteria.
extends Probe

var writes := 0


func _ready() -> void:
	remove_test_saves()
	use_fake_clock(MON_2026_10_05, 7, 0)
	CampaignState.new_campaign()
	CampaignState.commit(&"stamp", true)
	var path := CampaignState.save_path()
	check(FileAccess.file_exists(path), "the stamp writes the first save")
	var raw: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(path))
	var keys := ["schema_version", "campaign_start_utc", "campaign_start_tz_bias", "clock_witness",
		"current_day", "day_records", "document_instances", "world_artefacts", "relationships",
		"story_flags", "settings", "last_write_utc"]
	check(keys.all(func(k): return raw.has(k)), "every schema key is present")
	check(raw.day_records.size() == 14 and raw.schema_version == 1 and raw.campaign_start_utc != 0,
		"fourteen day records, schema version and start stamp populated")

	# A wrong field value persists exactly as entered.
	DocumentRegistry.load_directory("res://tests/fixtures/templates/")
	var doc := DocumentRegistry.print_document(&"test_permit")
	doc.set_value(&"permit_no", "PTW-00O4")  # letter O, wrong on purpose
	doc.location = CampaignState.Location.OUT_TRAY
	CampaignState.add_document(doc)
	await _settle()
	CampaignState.commit(&"field")
	await _settle()
	var reloaded := _reload()
	var back: DocumentInstance = CampaignState.document_instances.get(doc.instance_id)
	check(reloaded and back != null and back.get_value(&"permit_no") == "PTW-00O4", "a wrong value is saved exactly as entered")
	check(back != null and back.location == CampaignState.Location.OUT_TRAY, "document location persists")

	# Debounce: a burst writes once immediately and once trailing.
	CampaignState.committed.connect(func(_r): pass)
	await _settle()
	var before := _mtime_marker()
	CampaignState.story_flags["burst"] = 0
	for i in 20:
		CampaignState.story_flags["burst"] = i
		CampaignState.commit(&"pen")
	var after_burst: Variant = _flag_on_disk("burst")
	check(after_burst == 0, "a burst of commits writes once at the start (disk has %s)" % [after_burst])
	await _settle()
	check(_flag_on_disk("burst") == 19, "the trailing write lands after the debounce window")

	# A stale temp file from a killed write never affects the live save.
	var tmp := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	tmp.store_string("half a save")
	tmp.close()
	check(_reload() and CampaignState.story_flags.get("burst") == 19, "a half-written temp file is ignored; the live save is whole")

	# No manual save anywhere.
	check(not CampaignState.has_method("save") and not InputMap.has_action(&"save")
		and not InputMap.has_action(&"quicksave"), "no manual save API or input exists")

	# Phase boundary: the commit lands before subscribers act.
	var seen := []
	var on_phase := func(_a, _b): seen.append(_flag_on_disk("phase_marker"))
	DayPhase.phase_changed.connect(on_phase)
	CampaignState.story_flags["phase_marker"] = "before handout"
	set_local(MON_2026_10_05, 7, 30)
	DayPhase.phase_changed.disconnect(on_phase)
	check(seen == ["before handout"], "the save is written before phase-driven changes run")
	check(CampaignState.last_write_utc == WorldClock.now_unix(), "last_write_utc reflects that commit")

	# Force-quit and relaunch restores everything.
	CampaignState.relationships["sparks"] = {"trust": -2, "notes": ["late", "rude"]}
	CampaignState.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	var snapshot := CampaignState.to_dict()
	check(_reload() and CampaignState.to_dict() == snapshot, "close request writes; relaunch restores the whole campaign")
	check(WorldClock.get_campaign_day() == 1 and DayPhase.phase == DayPhase.Phase.HANDOUT, "resumes on the right day and phase")
	finish()


func _reload() -> bool:
	CampaignState.clear()
	return CampaignState.resume()


func _flag_on_disk(key: String) -> Variant:
	var raw: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(CampaignState.save_path()))
	return raw.story_flags.get(key)


func _mtime_marker() -> int:
	return FileAccess.get_modified_time(CampaignState.save_path())


## Lets the debounce window pass (run with --fixed-fps 60).
func _settle() -> void:
	for i in 60:
		await get_tree().process_frame
