# Audio standards (JIOH-66)

Source assets are authored clean, at 48 kHz, full band, and are never
pre-degraded. The period character is applied once, at the bus, so a retune
is an afternoon with `resources/audio/era_profile.tres` and never a re-record.

## Signal path

```
Master <- EraOut [HardLimiter] <- Era [LowPass 11 kHz, BitCrush (LOFI)]
                                           <- Ambience, Mechanical, Voice,
                                              Interface, FMV,
                                              Space_small, Space_hall, Space_dead
Master <- Monitor   (debug only, the one bus that skips Era)
```

* The project mixes at 22050 Hz (`audio/driver/mix_rate`), so nothing above
  11 kHz can reach the speakers; the low-pass shapes the roll-off.
* The bit-crush is Godot's `AudioEffectDistortion` in LOFI mode, which is a
  true bit-depth reduction; `BitCrushEffect` maps the profile's bit depth
  (8) onto its drive. Godot 4 cannot host a GDScript `AudioEffectInstance`,
  and a capture-and-replay crusher could fall silent, so there is no
  sample-and-hold stage yet: a GDExtension effect is the way to add one.
* Every player is put on one of the source buses. `EraBus` reroutes any player
  left on Master to Mechanical and warns in debug builds.
* Exactly three reverb characters, in `resources/audio/reverb_presets/`:
  `room_small` (print room, kitchen, file store, key cupboard), `room_hall`
  (reception, stairwell, corridors), `room_dead` (Janice's desk, the hatch,
  the yard door). `AcousticZones` sends each 3D sound to the space of the room
  it is made in. There is no fourth.
* The options menu (JIOH-9) adjusts Master, Ambience and Voice volumes only,
  never the Era chain.
* Debug console: `era off` bypasses the chain for A/B listening, `era on`
  restores it, live.
