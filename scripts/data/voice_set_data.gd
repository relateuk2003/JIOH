# scripts/data/voice_set_data.gd — JIOH-21: the barks a trade has, by
# situation. A reference only until JIOH-8 audio delivers the recordings;
# streams stay empty and the subtitle lines carry the character meanwhile.
class_name VoiceSetData
extends Resource

## Situations the hatch and reaction systems ask for (JIOH-30, JIOH-34).
const SITUATIONS: Array[StringName] = [&"greeting", &"waiting", &"accepted", &"queried", &"refused", &"walked"]

@export var voice_id: StringName = &""
## Pitch and pace a placeholder murmur uses until real lines exist.
@export var pitch: float = 1.0
@export var words_per_minute: float = 160.0
## situation -> Array of subtitle strings.
@export var lines: Dictionary = {}
## situation -> Array[AudioStream], filled by JIOH-8.
@export var streams: Dictionary = {}


func line_for(situation: StringName, pick: int) -> String:
	var options: Array = lines.get(situation, [])
	return "" if options.is_empty() else String(options[posmod(pick, options.size())])
