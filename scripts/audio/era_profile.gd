# scripts/audio/era_profile.gd — JIOH-66: the knobs that make the sound old.
# One file, applied to the Era chain at launch. Tune here, never in assets.
class_name EraProfile
extends Resource

## The Nyquist ceiling of a 22 kHz sample rate.
@export_range(2000.0, 20000.0) var lowpass_hz: float = 11000.0
@export_range(0.0, 1.0) var lowpass_resonance: float = 0.5
@export_range(2, 16) var bit_depth: int = 8
## The limiter only acts above its ceiling: below it the crushed signal
## passes at unity, steps intact.
@export var limiter_ceiling_db: float = -0.3
@export_range(0.01, 1.0) var limiter_release: float = 0.1
