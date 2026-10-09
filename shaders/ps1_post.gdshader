// shaders/ps1_post.gdshader — JIOH-55: colour quantisation and ordered dither
// in one pass.
//
// Runs on the display TextureRect that shows the internal viewport (the
// JIOH-42 spike layout), not inside the viewport: that avoids depending on
// screen-texture reads in the Compatibility renderer. The dither cell is
// indexed by internal pixel computed from UV, so the pattern is locked to the
// 320x240 grid whatever the upscale.
shader_type canvas_item;

#include "res://shaders/include/ps1_dither.gdshaderinc"

uniform vec2 internal_size = vec2(320.0, 240.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 pixel = ivec2(floor(UV * internal_size));
	COLOR = vec4(ps1_quantise(c.rgb, pixel, ps1_colour_levels, ps1_dither_enabled), 1.0);
}
