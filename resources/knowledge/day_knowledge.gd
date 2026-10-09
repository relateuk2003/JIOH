# resources/knowledge/day_knowledge.gd — JIOH-26: what the office knows on one
# campaign day, and the jobs whose packs are prepared that day for the next
# morning. Authored per day in resources/knowledge/day_NN.tres; never
# randomised.
class_name DayKnowledge
extends Resource

@export var day: int = 1
## Jobs whose packs are prepared today and handed out tomorrow.
@export var jobs_for_tomorrow: Array[JobRecord] = []
@export var facts: Array[Fact] = []
@export var contradictions: Array[ContradictionPair] = []
@export var phone_messages: Array[PhoneMessage] = []
@export var mail: Array[MailMessage] = []
@export var drawings: Array[DrawingSheet] = []
