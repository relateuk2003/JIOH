# tools/build_document_templates.gd — JIOH-20: writes the nine document
# templates and the pack matrix from the tables below.
#
#   godot --headless --path . res://tools/build_document_templates.tscn
#
# Run as a scene rather than with --script so the autoloads the rule scripts
# name (WorldClock, CampaignState) exist and the rules compile.
# The .tres files are the source of truth once a designer starts tuning them
# in the editor; this script is how they were first laid out, and it can be
# re-run while the layout is still being decided. Field rects are laid out
# top to bottom in printed order.
extends Node

const T := DocumentField.FieldType
const DIR := "res://resources/documents/templates/"
const ALL := PackMatrix.TRADES

# key, printed label, type, required, max length, source hint
const DOCS := {
	"job_sheet": {
		"name": "Job Sheet", "code": "JS-01", "trades": ALL, "sign": true, "stamp": true, "validity": 1,
		"fields": [
			["job_number", "Job No.", T.REFERENCE, true, 8, &"returned_sheets"],
			["date", "Date", T.DATE, true, 8, &"wall_planner"],
			["site", "Site", T.TEXT, true, 24, &"wall_planner"],
			["trade", "Trade", T.TEXT, true, 20, &"wall_planner"],
			["description", "Description of Works", T.MULTILINE, true, 120, &"terminal_mail"],
			["area", "Area / Level", T.TEXT, true, 16, &"site_drawings"],
			["raised_by", "Raised By", T.TEXT, true, 20, &""],
			["authorised_by", "Authorised (sign)", T.SIGNATURE, true, 0, &""],
		],
	},
	"permit_to_work": {
		"name": "Permit to Work", "code": "PTW-04/B", "sign": true, "stamp": true, "validity": 1,
		"trades": [&"electrician", &"carpenter", &"gas_engineer", &"fire_alarm_engineer", &"asbestos_surveyor", &"scaffolder"],
		"fields": [
			["permit_number", "Permit No.", T.REFERENCE, true, 8, &"permit_register"],
			["job_number", "Assoc. Job No.", T.REFERENCE, true, 8, &"returned_sheets"],
			["location", "Location of Work", T.TEXT, true, 24, &"site_drawings"],
			["valid_from_date", "Valid From (date)", T.DATE, true, 8, &"wall_planner"],
			["valid_from_time", "Valid From (time)", T.TIME, true, 5, &""],
			["valid_to_date", "Valid To (date)", T.DATE, true, 8, &"wall_planner"],
			["valid_to_time", "Valid To (time)", T.TIME, true, 5, &""],
			["works_description", "Works Description", T.MULTILINE, true, 120, &"terminal_mail"],
			["prec_isolation", "Isolation in place", T.TICKBOX, false, 0, &""],
			["prec_barriers", "Barriers / signage", T.TICKBOX, false, 0, &""],
			["prec_ppe", "PPE as RAMS", T.TICKBOX, false, 0, &""],
			["prec_fire", "Fire precautions", T.TICKBOX, false, 0, &""],
			["isolation_serial", "Isolation Cert. Serial", T.REFERENCE, false, 8, &"isolation_register"],
			["issuer_signature", "Issued By (sign)", T.SIGNATURE, true, 0, &""],
			["acceptor_signature", "Accepted By (sign)", T.SIGNATURE, false, 0, &""],
			["close_out", "Close Out (sign)", T.SIGNATURE, false, 0, &""],
		],
	},
	"hot_works_permit": {
		"name": "Hot Works Permit", "code": "HW-02", "sign": true, "stamp": true, "validity": 1,
		"trades": [&"gas_engineer", &"carpenter", &"flooring_fitter"],
		"fields": [
			["permit_number", "Hot Works No.", T.REFERENCE, true, 8, &"permit_register"],
			["parent_permit", "Permit to Work No.", T.REFERENCE, true, 8, &"permit_register"],
			["job_number", "Assoc. Job No.", T.REFERENCE, true, 8, &"returned_sheets"],
			["location", "Location of Work", T.TEXT, true, 24, &"site_drawings"],
			["fire_watch_minutes", "Fire Watch            min", T.NUMBER, true, 3, &""],
			["extinguisher_type", "Extinguisher Type", T.TEXT, true, 12, &"site_drawings"],
			["works_end_time", "Works End (time)", T.TIME, true, 5, &"terminal_mail"],
			["watch_end_time", "Fire Watch Ends (time)", T.TIME, true, 5, &""],
			["issuer_signature", "Issued By (sign)", T.SIGNATURE, true, 0, &""],
		],
	},
	"rams": {
		"name": "Risk Assessment & Method Statement", "code": "RA/MS-03 Rev C", "sign": true, "stamp": false, "validity": 7,
		"trades": [&"electrician", &"carpenter", &"gas_engineer", &"plasterer", &"decorator", &"flooring_fitter", &"fire_alarm_engineer", &"asbestos_surveyor", &"scaffolder"],
		"fields": [
			["assessment_ref", "Assessment Ref.", T.REFERENCE, true, 8, &"file_store"],
			["revision", "Rev.", T.TEXT, true, 2, &"file_store"],
			["job_number", "Job No.", T.REFERENCE, true, 8, &"returned_sheets"],
			["haz_height", "Work at height", T.TICKBOX, false, 0, &""],
			["haz_electrical", "Electrical", T.TICKBOX, false, 0, &""],
			["haz_dust", "Dust / fibres", T.TICKBOX, false, 0, &""],
			["haz_manual", "Manual handling", T.TICKBOX, false, 0, &""],
			["haz_hot", "Hot works", T.TICKBOX, false, 0, &""],
			["control_measures", "Control Measures", T.MULTILINE, true, 160, &"file_store"],
			["assessor", "Assessor", T.TEXT, true, 20, &"file_store"],
			["assessment_date", "Date Assessed", T.DATE, true, 8, &"file_store"],
			["review_date", "Review Date", T.DATE, false, 8, &""],
			["sign_off", "Signed Off (sign)", T.SIGNATURE, true, 0, &""],
		],
	},
	"access_key_docket": {
		"name": "Access & Key Docket", "code": "AK-07", "sign": true, "stamp": true, "validity": 1,
		"trades": [&"electrician", &"carpenter", &"gas_engineer", &"plasterer", &"decorator", &"flooring_fitter", &"fire_alarm_engineer", &"asbestos_surveyor", &"cleaner"],
		"fields": [
			["key_number", "Key No.", T.REFERENCE, true, 6, &"key_register"],
			["cabinet_position", "Cabinet Hook", T.TEXT, true, 4, &"key_cabinet"],
			["issued_to", "Issued To", T.TEXT, true, 20, &"wall_planner"],
			["issued_date", "Date Issued", T.DATE, true, 8, &""],
			["expected_return", "Expected Back (time)", T.TIME, true, 5, &""],
			["issue_signature", "Issued (sign)", T.SIGNATURE, true, 0, &""],
			["return_signature", "Returned (sign)", T.SIGNATURE, false, 0, &""],
		],
	},
	"delivery_note": {
		"name": "Delivery Note", "code": "DN-", "sign": true, "stamp": true, "validity": -1, "punch": true,
		"trades": [],
		"fields": [
			["supplier", "Supplier", T.TEXT, true, 24, &"terminal_mail"],
			["order_number", "Order No.", T.REFERENCE, true, 10, &"terminal_mail"],
			["items", "Items", T.MULTILINE, true, 160, &""],
			["quantity", "Qty", T.NUMBER, true, 4, &""],
			["received_by", "Received By (sign)", T.SIGNATURE, true, 0, &""],
			["date_received", "Date Received", T.DATE, true, 8, &""],
			["discrepancy", "Discrepancies", T.MULTILINE, false, 120, &""],
		],
	},
	"isolation_certificate": {
		"name": "Isolation Certificate", "code": "ISO-11", "sign": true, "stamp": false, "validity": 1,
		"trades": [&"electrician", &"gas_engineer", &"fire_alarm_engineer"],
		"fields": [
			["isolation_serial", "Isolation Serial", T.REFERENCE, true, 8, &"isolation_register"],
			["system_isolated", "System Isolated", T.TEXT, true, 24, &"site_drawings"],
			["isolation_points", "Points of Isolation", T.MULTILINE, true, 120, &"site_drawings"],
			["lock_number", "Lock No.", T.REFERENCE, true, 6, &"key_cabinet"],
			["tag_number", "Tag No.", T.REFERENCE, true, 6, &"key_cabinet"],
			["isolated_by", "Isolated By (sign)", T.SIGNATURE, true, 0, &""],
			["isolated_date", "Date Isolated", T.DATE, true, 8, &""],
			["isolated_time", "Time Isolated", T.TIME, true, 5, &""],
			["de_isolation", "De-isolated (sign)", T.SIGNATURE, false, 0, &""],
		],
	},
	"timesheet": {
		"name": "Weekly Timesheet", "code": "TS-", "sign": true, "stamp": false, "validity": -1,
		"trades": ALL,
		"fields": [
			["operative_name", "Operative", T.TEXT, true, 20, &""],
			["week_commencing", "W/C (Monday)", T.DATE, true, 8, &""],
			["hours_mon", "Mon hrs", T.NUMBER, false, 4, &""],
			["hours_tue", "Tue hrs", T.NUMBER, false, 4, &""],
			["hours_wed", "Wed hrs", T.NUMBER, false, 4, &""],
			["hours_thu", "Thu hrs", T.NUMBER, false, 4, &""],
			["hours_fri", "Fri hrs", T.NUMBER, false, 4, &""],
			["job_numbers", "Job Nos.", T.MULTILINE, false, 60, &""],
			["total", "Total hrs", T.NUMBER, true, 4, &""],
			["operative_signature", "Operative (sign)", T.SIGNATURE, true, 0, &""],
			["supervisor_signature", "Supervisor (sign)", T.SIGNATURE, true, 0, &""],
		],
	},
	"sign_in_book": {
		"name": "Visitors' Book", "code": "", "sign": false, "stamp": false, "validity": -1,
		"trades": ALL,
		"fields": [
			["name", "Name", T.TEXT, true, 20, &""],
			["company", "Company", T.TEXT, true, 20, &""],
			["time_in", "In", T.TIME, true, 5, &""],
			["time_out", "Out", T.TIME, false, 5, &""],
			["vehicle_reg", "Vehicle Reg.", T.TEXT, false, 8, &""],
		],
	},
}


func _ready() -> void:
	for doc_id in DOCS:
		var spec: Dictionary = DOCS[doc_id]
		var tpl := DocumentTemplate.new()
		tpl.doc_id = StringName(doc_id)
		tpl.display_name = spec.name
		tpl.form_code = spec.code
		var trades: Array[StringName] = []
		trades.assign(spec.trades)
		tpl.trades = trades
		tpl.requires_signature = spec.sign
		tpl.requires_stamp = spec.stamp
		tpl.requires_punch = spec.get("punch", false)
		tpl.validity_days = spec.validity
		var fields: Array[DocumentField] = []
		var y := 0.17
		for row in spec.fields:
			var f := DocumentField.new()
			f.key = StringName(row[0])
			f.printed_label = row[1]
			f.type = row[2]
			f.required = row[3]
			f.max_length = row[4]
			f.source_hint = row[5]
			var prev: DocumentField = fields.back() if not fields.is_empty() else null
			var h := 0.045
			match f.type:
				T.MULTILINE: h = 0.11
				T.SIGNATURE: h = 0.06
				T.TICKBOX: h = 0.035
			var w := 0.54
			match f.type:
				T.TICKBOX: w = 0.04
				T.DATE: w = 0.24
				T.TIME: w = 0.14
				T.NUMBER: w = 0.12
			# Ticked precautions share a line, four across; a time sits on the
			# same line as the date before it, as the paper forms print them.
			if prev and f.type == T.TICKBOX and prev.type == T.TICKBOX and prev.rect.position.x < 0.80:
				f.rect = Rect2(prev.rect.position.x + 0.14, prev.rect.position.y, w, h)
			elif prev and f.type == T.TIME and prev.type == T.DATE:
				f.rect = Rect2(0.70, prev.rect.position.y, w, prev.rect.size.y)
			else:
				f.rect = Rect2(0.40 if f.type != T.TICKBOX else 0.12, y, w, h)
				y += h + 0.012
			fields.append(f)
		tpl.fields = fields
		tpl.validation_rules = _rules(doc_id)
		var err := ResourceSaver.save(tpl, DIR + doc_id + ".tres")
		print("%s: %d fields, bottom at %.2f (%s)" % [doc_id, fields.size(), y, error_string(err)])
	_matrix()
	get_tree().quit()


## The cross-references from the paperwork design doc, as rule resources.
func _rules(doc_id: String) -> Array[ValidationRule]:
	var r: Array[ValidationRule] = []
	match doc_id:
		"job_sheet":
			r.append(_job("job_number", &"job_number", Failure.Code.WRONG_JOB_NUMBER))
			r.append(_job("date", &"date", Failure.Code.WRONG_DATE_IN_FIELD))
			r.append(_job("trade", &"trade", Failure.Code.WRONG_TRADE))
		"permit_to_work":
			r.append(_job("job_number", &"job_number", Failure.Code.WRONG_JOB_NUMBER))
			var range_rule := DateRangeRule.new()
			range_rule.rule_id = &"ptw_covers_job"
			range_rule.category = ValidationRule.Category.EXPIRED
			r.append(range_rule)
			r.append(_sibling("job_number", &"job_sheet", &"job_number"))
			r.append(_sibling("isolation_serial", &"isolation_certificate", &"isolation_serial"))
			var unclosed := UnclosedPredecessorRule.new()
			unclosed.rule_id = &"ptw_unclosed_predecessor"
			unclosed.category = ValidationRule.Category.INHERITED
			r.append(unclosed)
		"hot_works_permit":
			r.append(_job("job_number", &"job_number", Failure.Code.WRONG_JOB_NUMBER))
			r.append(_sibling("parent_permit", &"permit_to_work", &"permit_number"))
			r.append(_sibling("job_number", &"job_sheet", &"job_number"))
		"rams":
			r.append(_job("job_number", &"job_number", Failure.Code.WRONG_JOB_NUMBER))
			r.append(_sibling("job_number", &"job_sheet", &"job_number"))
			var age := FieldDateAgeRule.new()
			age.rule_id = &"rams_assessment_age"
			age.category = ValidationRule.Category.EXPIRED
			r.append(age)
		"access_key_docket":
			r.append(_job("key_number", &"key_number", Failure.Code.WRONG_JOB_NUMBER))
			r.append(_job("issued_date", &"date", Failure.Code.WRONG_DATE_IN_FIELD))
		"isolation_certificate":
			r.append(_job("isolation_serial", &"isolation_serial", Failure.Code.WRONG_JOB_NUMBER))
			r.append(_job("isolated_date", &"date", Failure.Code.WRONG_DATE_IN_FIELD))
	return r


func _job(field: String, prop: StringName, code: Failure.Code) -> FieldMatchesJobRule:
	var rule := FieldMatchesJobRule.new()
	rule.rule_id = StringName("%s_matches_job_%s" % [field, prop])
	rule.category = ValidationRule.Category.CONTRADICTORY
	rule.field_key = StringName(field)
	rule.job_property = prop
	rule.failure_code = code
	return rule


func _sibling(field: String, other: StringName, other_field: StringName) -> SiblingMatchRule:
	var rule := SiblingMatchRule.new()
	rule.rule_id = StringName("%s_matches_%s" % [field, other])
	rule.category = ValidationRule.Category.CONTRADICTORY
	rule.field_key = StringName(field)
	rule.sibling_doc_id = other
	rule.sibling_field_key = other_field
	return rule


## The pack matrix from the paperwork design doc. Bold cells are required;
## plain "Yes" cells are expected.
func _matrix() -> void:
	var m := PackMatrix.new()
	var rows: Array[PackRequirement] = []
	rows.append(_row(&"electrician", [&"job_sheet", &"permit_to_work", &"rams", &"isolation_certificate"], [&"access_key_docket"]))
	var carpenter := _row(&"carpenter", [&"job_sheet"], [&"permit_to_work", &"rams", &"access_key_docket"])
	carpenter.conditional_docs.append(_cond(&"hot_works_permit", [&"cutting"]))
	rows.append(carpenter)
	rows.append(_row(&"gas_engineer", [&"job_sheet", &"permit_to_work", &"hot_works_permit", &"rams", &"isolation_certificate"], [&"access_key_docket"]))
	rows.append(_row(&"plasterer", [&"job_sheet"], [&"rams", &"access_key_docket"]))
	rows.append(_row(&"decorator", [&"job_sheet"], [&"rams", &"access_key_docket"]))
	var flooring := _row(&"flooring_fitter", [&"job_sheet"], [&"rams", &"access_key_docket"])
	flooring.conditional_docs.append(_cond(&"hot_works_permit", [&"hot_bonding"]))
	rows.append(flooring)
	rows.append(_row(&"fire_alarm_engineer", [&"job_sheet", &"permit_to_work", &"rams", &"access_key_docket", &"isolation_certificate"], []))
	rows.append(_row(&"asbestos_surveyor", [&"job_sheet", &"permit_to_work", &"rams", &"access_key_docket"], []))
	rows.append(_row(&"cleaner", [&"access_key_docket"], [&"job_sheet"]))
	rows.append(_row(&"scaffolder", [&"job_sheet", &"permit_to_work", &"rams"], []))
	m.rows = rows
	var err := ResourceSaver.save(m, "res://resources/documents/pack_matrix.tres")
	print("pack_matrix: %d rows (%s)" % [rows.size(), error_string(err)])


func _row(trade: StringName, required: Array, expected: Array) -> PackRequirement:
	var r := PackRequirement.new()
	r.trade = trade
	r.required_docs.assign(required)
	r.expected_docs.assign(expected)
	return r


func _cond(doc_id: StringName, kinds: Array) -> ConditionalDoc:
	var c := ConditionalDoc.new()
	c.doc_id = doc_id
	c.when_job_kind_in.assign(kinds)
	c.blocking = true
	return c
