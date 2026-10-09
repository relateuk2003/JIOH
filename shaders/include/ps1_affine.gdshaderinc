// shaders/include/ps1_affine.gdshaderinc — JIOH-51: affine texture mapping.
//
// Godot's shading language has no `noperspective` (JIOH-42 decision record),
// so this uses the multiply-by-w trick: the vertex stage writes
// ps1_affine_uvw = vec3(UV * w, w); the GPU's perspective-correct
// interpolation of both then cancels, and dividing them back out in the
// fragment stage leaves UVs interpolated linearly in screen space.
//
// Varyings can only be written in vertex() itself, so the including shader
// assigns ps1_affine_uvw there:
//     ps1_affine_uvw = vec3(UV * POSITION.w, POSITION.w);

global uniform bool ps1_affine_enabled;

varying vec3 ps1_affine_uvw;

// Mixes perspective-correct and affine UVs. strength 1.0 is full affine;
// 0.0 keeps text on held documents and screens square.
vec2 ps1_affine_uv(vec2 perspective_uv, vec3 uvw, float strength) {
	if (!ps1_affine_enabled || strength <= 0.0) {
		return perspective_uv;
	}
	return mix(perspective_uv, uvw.xy / uvw.z, strength);
}
