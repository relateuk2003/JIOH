# resources/knowledge/mail_message.gd — JIOH-26: one mail in the terminal's
# inbox. {day:N} in the body is rendered as the weekday and date.
class_name MailMessage
extends Resource

@export var message_id: StringName = &""
@export var available_from_day: int = 1
@export var sender: String = ""
@export var subject: String = ""
@export_multiline var body: String = ""
@export var fact_ids: Array[StringName] = []
