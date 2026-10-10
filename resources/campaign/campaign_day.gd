# resources/campaign/campaign_day.gd — JIOH-15: one date in the fortnight.
class_name CampaignDay
extends Resource

## 1..14, derived from the date, never from a counter.
@export var index: int = 0
## Local date as "YYYY-MM-DD".
@export var date: String = ""
## Days since 1970-01-01 of the local date.
@export var epoch_day: int = 0
@export var is_working_day: bool = false
## 1..10 for working days, 0 for weekends. Content is authored against this
## ordinal so the story runs the same whichever weekday the player starts on.
@export var working_day_ordinal: int = 0
@export var scheduled_trades: Array[StringName] = []
@export var story_beat_id: StringName = &""
