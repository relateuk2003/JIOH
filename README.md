# Janice Is On Holiday

A first-person game about preparing paperwork in an empty office, played over fourteen real days. Godot 4.5, Compatibility renderer (JIOH-42).

Tickets live in Jira under the JIOH project. Commits and PRs name the ticket they close.

## Layout

| Path | What |
| --- | --- |
| `autoload/world_clock.gd` | The only source of time (JIOH-14). Nothing else may call `Time.get_*`. |
| `autoload/campaign_state.gd` | The fourteen-day calendar stamped at New Game (JIOH-15). |
| `autoload/day_phase.gd` | Closed / pre-open / handout / working / cutoff / wind-down (JIOH-16). |
| `autoload/document_registry.gd` | Every document template by `doc_id` (JIOH-18). |
| `resources/campaign/day_schedule.tres` | Phase boundaries. Tune here, not in code. |
| `resources/documents/templates/` | One `.tres` per document type. Drop one in and it registers. |
| `scripts/documents/` | `DocumentInstance` and its signature and stamp marks. |
| `tools/debug/` | Time console and fortnight soak. Debug builds only; excluded from release exports. |
| `addons/document_inspector/` | Editor dock listing every template and its fields. Enable it in Project Settings → Plugins. |

## Debug time console

In a debug build press backtick. `goto 11 wind_down`, `skip 2h`, `freeze`, `thaw`, `rate 60`, `now`, `reset`.

## Tests

Probes follow the OTIF pattern: each is a scene under `tests/` that prints `PROBE OK` / `PROBE FAIL` and exits non-zero on failure.

```sh
GODOT=/path/to/godot tests/run_all.sh                                    # everything
godot --headless --path . res://tests/DayPhaseProbe.tscn                  # one probe
godot --headless --path . --script res://tools/debug/soak_fortnight.gd    # the fortnight soak
tools/check_time_calls.sh                                                 # no OS clock reads outside WorldClock
```
