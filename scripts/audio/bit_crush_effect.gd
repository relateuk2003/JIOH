# scripts/audio/bit_crush_effect.gd — JIOH-66: the era's bit depth.
#
# Godot 4 cannot host a GDScript AudioEffectInstance (its _process takes raw
# pointers), and a capture-and-replay workaround through a generator was
# tried and could fall silent when the generator stopped draining. So the
# crush is the stock AudioEffectDistortion in LOFI mode, which is a true
# bit-depth reduction: it rounds every sample to 1 / 2^(2 + 14 (1 - drive)).
# This maps a bit depth onto that drive. Sample-and-hold has no stock
# equivalent; the 22050 Hz mix carries that part of the sound until a
# GDExtension effect replaces this.
class_name BitCrushEffect
extends RefCounted


## The LOFI drive that rounds to `bits` bits, sign included.
static func drive_for(bits: int) -> float:
	return clampf(1.0 - float(bits - 3) / 14.0, 0.0, 1.0)


## What one sample becomes at `bits` bits, as the effect computes it.
static func quantise(sample: float, bits: int) -> float:
	var mult := pow(2.0, bits - 1)
	return floorf(sample * mult + 0.5) / mult


## Sets an existing LOFI distortion to the given depth.
static func configure(effect: AudioEffectDistortion, bits: int) -> void:
	effect.mode = AudioEffectDistortion.MODE_LOFI
	effect.pre_gain = 0.0
	effect.post_gain = 0.0
	effect.keep_hf_hz = 20000.0
	effect.drive = drive_for(bits)
