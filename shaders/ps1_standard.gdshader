// shaders/ps1_standard.gdshader — JIOH-47 / JIOH-51: the base material for
// every prop, wall and character. Vertex snapping and affine mapping are on by
// default; resources/materials/ps1_base_material.tres is the authored parent.
// Lighting is per-vertex; fog comes from the PS1 environment (JIOH-55).
shader_type spatial;
render_mode skip_vertex_transform, vertex_lighting, specular_disabled, cull_back;

#include "res://shaders/include/ps1_vertex.gdshaderinc"
#include "res://shaders/include/ps1_affine.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);

group_uniforms snapping;
uniform bool snap_enabled = true;
uniform float snap_strength : hint_range(0.0, 1.0) = 1.0;
// Within this view distance (metres) the snap fades out, for held objects.
// 0 disables the fade.
uniform float snap_disable_distance = 0.0;

group_uniforms affine;
uniform float affine_strength : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	UV *= uv_scale;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	float strength = snap_enabled ? snap_strength : 0.0;
	if (snap_disable_distance > 0.0) {
		strength *= smoothstep(snap_disable_distance * 0.5, snap_disable_distance, -VERTEX.z);
	}
	POSITION = ps1_snap(clip, ps1_snap_resolution, strength);
	ps1_affine_uvw = vec3(UV * POSITION.w, POSITION.w);
}

void fragment() {
	vec2 uv = ps1_affine_uv(UV, ps1_affine_uvw, affine_strength);
	ALBEDO = albedo.rgb * texture(albedo_texture, uv).rgb;
}
