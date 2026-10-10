# resources/knowledge/phone_message.gd — JIOH-26: one message on the
# answerphone tape. The transcript is for designers and voice actors; the
# game never shows it, as text or subtitle, anywhere.
class_name PhoneMessage
extends Resource

@export var message_id: StringName = &""
@export var available_from_day: int = 1
@export var caller: String = ""
## Never displayed. {day:N} tokens are spoken as the weekday.
@export_multiline var transcript: String = ""
## The recording. Until one exists, a placeholder murmur of the same length
## plays, so the machine can be tested.
@export var audio: AudioStream
@export var fact_ids: Array[StringName] = []


func spoken_seconds() -> float:
	if audio:
		return audio.get_length()
	return clampf(transcript.length() * 0.065, 2.0, 30.0)
