# scripts/data/roster_validator.gd — JIOH-21: authoring checks on the roster.
# Shared by the editor script (tools/validate_roster.gd) and the CI runner
# (tools/validate_roster_cli.tscn). Each problem names the offending trade.
class_name RosterValidator
extends RefCounted


static func problems(roster: TradeRoster, matrix: PackMatrix = null) -> PackedStringArray:
	var out := PackedStringArray()
	if roster == null:
		out.append("roster missing")
		return out
	var seen: Array[StringName] = []
	var pairs: Array = []
	for i in roster.trades.size():
		var t: TradespersonData = roster.trades[i]
		if t == null:
			out.append("entry %d is empty" % i)
			continue
		var who := String(t.trade_id) if t.trade_id != &"" else "entry %d" % i
		if t.trade_id == &"":
			out.append("%s: trade_id unassigned" % who)
		elif t.trade_id in seen:
			out.append("%s: duplicate trade_id" % who)
		seen.append(t.trade_id)
		if t.voice_set == null:
			out.append("%s: no voice set" % who)
		if t.body_profile == null:
			out.append("%s: no body profile" % who)
		if t.display_name == "" or t.company == "":
			out.append("%s: name or company blank" % who)
		out.append_array(_window_problems(who, t.punctuality))
		var pair := [t.patience_seconds, t.error_tolerance]
		if pair in pairs:
			out.append("%s: shares patience and tolerance %s with another trade" % [who, pair])
		pairs.append(pair)
		if t.error_tolerance < 0 or t.error_tolerance > 4:
			out.append("%s: error tolerance %d outside 0..4" % [who, t.error_tolerance])
		if matrix:
			var docs: Array = matrix.documents_for(t.trade_id, &"*").required
			if Array(t.required_document_types) != docs:
				out.append("%s: required documents %s differ from the pack matrix %s" % [who, t.required_document_types, docs])
	return out


static func _window_problems(who: String, p: PunctualityProfile) -> PackedStringArray:
	var out := PackedStringArray()
	if p == null:
		out.append("%s: no punctuality profile" % who)
		return out
	# The authored window, not the variance tail: the scheduler clamps
	# samples into Handout (JIOH-28).
	var earliest := p.window_start_minutes
	var latest := p.window_end_minutes
	if p.window_end_minutes < p.window_start_minutes:
		out.append("%s: arrival window ends before it starts" % who)
	if latest > PunctualityProfile.HANDOUT_MINUTES:
		out.append("%s: arrival window runs past 10:00, outside Handout" % who)
	if earliest < 0 and not p.lets_self_in:
		out.append("%s: arrival window starts before 07:30, outside Handout" % who)
	return out
