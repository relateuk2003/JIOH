// shaders/include/ps1_vertex.gdshaderinc — JIOH-47: vertex snapping.
// The only place the snap maths exists. Every spatial shader includes it.
//
// Snapping happens in clip space after the perspective divide, on a virtual
// grid coarser than the internal render resolution. That reproduces the PS1's
// fixed-point screen coordinates; snapping in object or world space produces a
// different and wrong-looking artefact.

global uniform bool ps1_snap_enabled;
global uniform vec2 ps1_snap_resolution;

// Snaps a clip-space position to a grid of `grid` virtual pixels. `strength`
// blends from unsnapped (0) to fully snapped (1).
vec4 ps1_snap(vec4 clip_pos, vec2 grid, float strength) {
	if (!ps1_snap_enabled || strength <= 0.0 || clip_pos.w <= 0.0) {
		return clip_pos;
	}
	vec2 half_grid = grid * 0.5;
	vec2 ndc = clip_pos.xy / clip_pos.w;
	vec2 snapped = floor(ndc * half_grid + 0.5) / half_grid;
	return vec4(mix(ndc, snapped, strength) * clip_pos.w, clip_pos.zw);
}
