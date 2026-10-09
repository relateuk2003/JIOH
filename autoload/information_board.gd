# autoload/information_board.gd — JIOH-26: the day's authored facts, for the
# source props to read from.
#
# Holds every fact authored for the fortnight and answers queries. query()
# returns every matching fact, contradictory ones included, in authored order
# and never sorted by truth: anything that resolves an ambiguity on the
# player's behalf is a bug. Which fact is true lives in the contradiction
# pairs and the job records, which only the validator and the auditor read.
extends Node

const DIR := "res://resources/knowledge/"

var days: Dictionary = {}  # day -> DayKnowledge


func _ready() -> void:
	load_directory(DIR)


func load_directory(dir: String) -> void:
	days.clear()
	for file in ResourceLoader.list_directory(dir):
		if file.begins_with("day_") and (file.ends_with(".tres") or file.ends_with(".res")):
			var k := load(dir.path_join(file)) as DayKnowledge
			if k:
				days[k.day] = k


## Every fact findable on a campaign day (today's and earlier days').
func facts_on(day: int) -> Array[Fact]:
	var out: Array[Fact] = []
	var keys := days.keys()
	keys.sort()
	for d in keys:
		for f in (days[d] as DayKnowledge).facts:
			if f.available_from_day <= day:
				out.append(f)
	return out


## Everything any source says about a subject's field today.
func query(subject_id: StringName, key: StringName, day: int = -1) -> Array[Fact]:
	var on := WorldClock.get_campaign_day() if day < 0 else day
	return facts_on(on).filter(func(f): return f.subject_id == subject_id and f.answers(key))


## What one source carries today, for the prop that is that source.
func from_source(source: StringName, day: int = -1) -> Array[Fact]:
	var on := WorldClock.get_campaign_day() if day < 0 else day
	return facts_on(on).filter(func(f): return source in f.sources)


## The jobs whose packs are prepared on a day.
func jobs_prepared_on(day: int) -> Array[JobRecord]:
	var k: DayKnowledge = days.get(day)
	var out: Array[JobRecord] = []
	if k:
		out.append_array(k.jobs_for_tomorrow)
	return out


func fact(fact_id: StringName) -> Fact:
	for k in days.values():
		for f in (k as DayKnowledge).facts:
			if f.fact_id == fact_id:
				return f
	return null


## How a source writes a campaign day: weekday names and the date.
static func describe_day(day: int) -> Dictionary:
	var d := CampaignState.get_day(day)
	if d == null:
		return {"weekday": "", "short": "", "dom": 0, "form": ""}
	var names := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var wd := WorldClock.weekday_of(d.epoch_day)
	return {"weekday": names[wd], "short": names[wd].substr(0, 3), "dom": int(d.date.substr(8, 2)),
		"form": WorldClock.form_date(d.epoch_day)}


## A fact's value as a source would put it: "day:4" becomes the weekday.
static func spoken_value(f: Fact) -> String:
	var n := f.day_value()
	return describe_day(n).weekday if n > 0 else f.value


func phone_messages_on(day: int) -> Array[PhoneMessage]:
	var out: Array[PhoneMessage] = []
	for k in _ordered():
		for m in k.phone_messages:
			if m.available_from_day <= day:
				out.append(m)
	return out


func mail_on(day: int) -> Array[MailMessage]:
	var out: Array[MailMessage] = []
	for k in _ordered():
		for m in k.mail:
			if m.available_from_day <= day:
				out.append(m)
	return out


func drawings_on(day: int) -> Array[DrawingSheet]:
	var out: Array[DrawingSheet] = []
	for k in _ordered():
		for d in k.drawings:
			if d.available_from_day <= day:
				out.append(d)
	return out


## Replaces {day:N} with the weekday and date, as a person would write it.
static func render_tokens(text: String) -> String:
	var re := RegEx.create_from_string("\\{day:(\\d+)\\}")
	var out := text
	for m in re.search_all(text):
		var info := describe_day(int(m.get_string(1)))
		out = out.replace(m.get_string(), "%s %d" % [info.weekday, info.dom])
	return out


func _ordered() -> Array[DayKnowledge]:
	var out: Array[DayKnowledge] = []
	var keys := days.keys()
	keys.sort()
	for d in keys:
		out.append(days[d])
	return out
