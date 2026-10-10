# scripts/data/punctuality_profile.gd — JIOH-21: when a trade turns up.
# Offsets are minutes from 07:30, the start of Handout. Read by the arrival
# scheduler (JIOH-28); punctuality is the first thing the player learns about
# anybody, so it is authored per trade, never generated.
class_name PunctualityProfile
extends Resource

## Handout runs 07:30 to 10:00: offsets 0 to 150.
const HANDOUT_MINUTES := 150

@export var window_start_minutes: float = 0.0
@export var window_end_minutes: float = 30.0
## Spread of the seeded sample around the window, in minutes. Samples are
## clamped into Handout, so a tail past the window is allowed.
@export var variance_minutes: float = 5.0
## Minutes later per strike on the relationship (JIOH-28 reads strikes).
@export var drift_per_campaign_day: float = 0.0
## Arrives before Handout opens and lets themselves in (the cleaner). Only a
## profile with this set may start before offset 0.
@export var lets_self_in: bool = false
