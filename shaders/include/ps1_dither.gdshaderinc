// shaders/include/ps1_dither.gdshaderinc — JIOH-55: ordered dither and
// colour quantisation.
//
// A 4x4 Bayer matrix, not noise: the regularity of the pattern is the
// artefact. Indexed by internal-resolution pixel, so at 4x upscale each cell
// is a block four output pixels across.

global uniform bool ps1_dither_enabled;
global uniform float ps1_colour_levels;

const mat4 PS1_BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0));

// Threshold in (0, 1) for an internal pixel.
float ps1_bayer(ivec2 pixel) {
	ivec2 m = ivec2(pixel.x & 3, pixel.y & 3);
	return (PS1_BAYER[m.x][m.y] + 0.5) / 16.0;
}

// Quantises to exactly `levels` values per channel (k / (levels - 1)),
// dithering with the Bayer threshold, or rounding when dither is off.
vec3 ps1_quantise(vec3 colour, ivec2 pixel, float levels, bool dither) {
	float steps = max(levels - 1.0, 1.0);
	float threshold = dither ? ps1_bayer(pixel) : 0.5;
	return clamp(floor(colour * steps + threshold) / steps, 0.0, 1.0);
}
