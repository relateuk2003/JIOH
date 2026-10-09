# scripts/interaction/interaction_data.gd — JIOH-50: authored data an
# Interactable carries. Lives under resources/interactions/.
class_name InteractionData
extends Resource

## What examine shows when the object has nothing better (JIOH-9 owns how).
@export_multiline var examine_text: String = ""
## Refusal reasons this object gives, by verb name. Optional; code supplies a
## specific reason when none is authored.
@export var refusals: Dictionary = {}
