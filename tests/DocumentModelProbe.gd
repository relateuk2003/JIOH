# tests/DocumentModelProbe.gd — JIOH-18 acceptance criteria.
extends Probe


func _ready() -> void:
	use_fake_clock(MON_2026_10_05, 9, 0)
	CampaignState.new_campaign()

	# A dropped-in .tres registers and prints with no code change.
	DocumentRegistry.load_directory("res://tests/fixtures/templates/")
	check(DocumentRegistry.has_template(&"test_permit"), "a template .tres registers from its directory")
	var tpl := DocumentRegistry.get_template(&"test_permit")
	check(tpl.get_field(&"permit_no").rect == Rect2(0.1, 0.1, 0.4, 0.05), "field rects come from the resource")

	# Provenance from day 1, then a copy raised on day 3.
	var original := DocumentRegistry.print_document(&"test_permit")
	check(original.raised_on_day == 1, "first sheet raised on day 1")
	set_local(MON_2026_10_05 + 2, 11, 0)
	var copy := DocumentRegistry.print_document(&"test_permit", original.instance_id)
	check(copy.raised_on_day == 3, "copy raised on day 3 (got %d)" % copy.raised_on_day)
	check(copy.copied_from_instance_id == original.instance_id, "copy points back at the earlier sheet")
	check(copy.instance_id != original.instance_id and String(copy.instance_id).length() == 36, "instances get distinct UUIDs")

	# Fill, sign, stamp (wheel wound to the wrong day), lodge, then round-trip.
	copy.set_value(&"permit_no", "PTW-0042")
	copy.set_value(&"location", "Plant room B")
	copy.sign(&"player")
	copy.apply_stamp(&"date_stamp", "2026-10-02")
	copy.punched = true
	copy.lodge(&"hole_electrician")
	var saved := copy.to_dict()
	var json := JSON.stringify(saved)
	var restored := DocumentInstance.from_dict(JSON.parse_string(json))
	check(restored != null and restored.template == tpl, "restored instance resolves to the same template by doc_id")
	check(restored.get_value(&"permit_no") == "PTW-0042" and restored.get_value(&"location") == "Plant room B", "filled values restored")
	check(restored.signature.signer == &"player" and restored.signature.signed_on_day == 3, "signature restored")
	check(restored.stamp.stamped_date == "2026-10-02", "stamp keeps the wheel's date, not the real one")
	check(restored.punched and restored.lodged_in_hole == &"hole_electrician", "punch and lodgement restored")
	check(JSON.stringify(restored.to_dict()) == json, "full instance survives a JSON round trip exactly")
	check(not saved.has("fields") and not saved.has("display_name"), "no template data is written into the save")

	# Paper cannot be asked whether it is correct.
	check(not copy.has_method("is_valid") and not ("errors" in copy) and not ("dirty" in copy),
		"DocumentInstance has no validity method, errors or dirty flag")

	# A template patched between builds: saved instances rebind to the new one.
	var patched := tpl.duplicate(true) as DocumentTemplate
	patched.form_code = "TST-01/B"
	DocumentRegistry.register_template(patched)
	var rebound := DocumentInstance.from_dict(saved)
	check(rebound.template.form_code == "TST-01/B", "loaded instances rebind to the updated template")

	finish()
