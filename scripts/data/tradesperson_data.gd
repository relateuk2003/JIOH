# scripts/data/tradesperson_data.gd — JIOH-21: everything the arrival,
# handout, reaction and returns systems need about one trade. Authored and
# read-only: what changes during a campaign lives in RelationshipState.
#
# Patience and error tolerance are deliberately separate axes. Patience is how
# long they will stand at the hatch; tolerance is how many wrong packs they
# absorb before refusing becomes their default. Never fold them into one.
class_name TradespersonData
extends Resource

@export var trade_id: StringName = &""
@export var display_name: String = ""
@export var surname: String = ""
@export var company: String = ""
@export var punctuality: PunctualityProfile
## Seconds at the hatch before they give up (JIOH-37).
@export var patience_seconds: float = 180.0
## Substantively wrong packs absorbed before escalating from queried to
## refused. 0..4 across the roster.
@export_range(0, 4) var error_tolerance: int = 2
## How long they spend reading each page of a handed-over pack (JIOH-30).
@export var read_pace_seconds_per_page: float = 4.0
@export var voice_set: VoiceSetData
@export var body_profile: BodyProfileData
## Documents their default pack must hold, mirrored from the pack matrix's
## default row; the roster validator keeps the two in step.
@export var required_document_types: Array[StringName] = []
