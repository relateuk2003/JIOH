# scripts/slice/slice_bootstrap.gd — JIOH-82: the vertical slice opens on
# campaign day 3 of a fortnight already under way.
#
# Days 1 and 2 have happened: their mornings are settled, and on day 2's
# afternoon somebody (not the player) prepared and lodged packs for two of
# day 3's trades. One is right. The other carries a job number that does not
# match the job: nothing about it looks wrong, and it fails at the hatch in
# front of the trade, which is how the player learns what a failure is.
#
# Writes only into CampaignState. Never scores anything: the validator runs
# at the hatch and nowhere else (JIOH-29).
class_name SliceBootstrap
extends RefCounted

const SETTING := "jioh/slice/seed_new_campaign"
const MATRIX := "res://resources/documents/pack_matrix.tres"
const OPENING_DAY := 3
## When the previous evening's packs went into their holes, local time.
const LODGED_AT_MINUTE := 15 * 60 + 10


## True for slice builds: New Game opens on day 3 with the seeded packs.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, false))


## Starts a campaign whose day 3 is today, with the previous evening's work
## in the holes. Returns the trades seeded: [right, wrong].
static func seed() -> Array[StringName]:
	CampaignState.new_campaign()
	var shift := OPENING_DAY - 1
	CampaignState.campaign_start_utc -= shift * 86400
	CampaignState.campaign_start_epoch_day -= shift
	CampaignState.generate_calendar(CampaignState.campaign_start_epoch_day)
	for day in range(1, OPENING_DAY):
		CampaignState.day_records[day - 1]["hatch_settled"] = true
	var seeded: Array[StringName] = []
	for job in InformationBoard.live_jobs_on(OPENING_DAY):
		if seeded.size() == 2:
			break
		if job.trade in seeded:
			continue
		_lodge(job, prepared_pack(job, OPENING_DAY, seeded.size() == 1))
		seeded.append(job.trade)
	CampaignState.story_flags["slice_seeded"] = true
	CampaignState.campaign_started.emit()
	CampaignState.commit(&"slice_seeded", true)
	return seeded


## A pack for a job on its handout day, filled in the way a careful person
## fills it. With `mismatch`, the job number on every sheet is one digit out.
static func prepared_pack(job: JobRecord, day: int, mismatch := false) -> Array[DocumentInstance]:
	var e := CampaignState.get_day(day).epoch_day
	var needed: Dictionary = (load(MATRIX) as PackMatrix).documents_for(job.trade, job.job_kind)
	var ids: Array[StringName] = []
	ids.append_array(needed.required)
	ids.append_array(needed.expected)
	var job_number := job.job_number
	if mismatch:
		job_number = _off_by_one(job_number)
	var known := {&"job_number": job_number, &"trade": String(job.trade).capitalize(),
		&"location": job.location, &"site": job.site, &"key_number": job.key_number,
		&"permit_number": job.permit_number, &"isolation_serial": job.isolation_serial,
		&"previous_job_number": job.previous_job_number}
	var printed := WorldClock.utc_of_local_midnight(e - 1) + 14 * 3600
	var docs: Array[DocumentInstance] = []
	for id in ids:
		var doc := DocumentRegistry.print_document(id)
		doc.raised_on_day = day - 1
		doc.printed_at_unix = printed
		for f in doc.template.fields:
			match f.type:
				DocumentField.FieldType.DATE: doc.set_value(f.key, WorldClock.form_date(e))
				DocumentField.FieldType.TIME: doc.set_value(f.key, "08:00")
				DocumentField.FieldType.NUMBER: doc.set_value(f.key, "1")
				DocumentField.FieldType.TICKBOX: doc.set_value(f.key, true)
				DocumentField.FieldType.SIGNATURE: doc.set_value(f.key, {"by": "janice"})
				_: doc.set_value(f.key, "X")
		for k in known:
			if doc.template.get_field(k) and String(known[k]) != "":
				doc.set_value(k, known[k])
		if doc.template.requires_stamp:
			doc.apply_stamp(&"received", WorldClock.date_string(e))
		if id == &"rams":
			doc.set_value(&"assessment_date", WorldClock.form_date(e - 2))
		docs.append(doc)
	return docs


static func _lodge(job: JobRecord, docs: Array[DocumentInstance]) -> void:
	var day := OPENING_DAY - 1
	var at := WorldClock.utc_of_local_midnight(CampaignState.get_day(day).epoch_day) + LODGED_AT_MINUTE * 60
	var ids := PackedStringArray()
	for doc in docs:
		doc.lodged_in_hole = job.trade
		doc.lodged_at_unix = at
		doc.location = CampaignState.Location.LODGED
		CampaignState.add_document(doc)
		ids.append(String(doc.instance_id))
	CampaignState.lodgement_log.append({"kind": "lodged", "trade": String(job.trade),
		"ids": ids, "unix": at, "day": day})
	CampaignState.day_records[day - 1].lodgements_made += 1


## The last digit of a reference, one out: the kind of slip nobody sees.
static func _off_by_one(reference: String) -> String:
	for i in range(reference.length() - 1, -1, -1):
		if reference[i].is_valid_int():
			var d := (int(reference[i]) + 1) % 10
			return reference.substr(0, i) + str(d) + reference.substr(i + 1)
	return reference + "1"
