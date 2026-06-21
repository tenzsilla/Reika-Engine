package render

import "../rmath"

// Reika fog
//
// The PS1 fog was an artistic system, and not just a z-fighting workaround.
// It was done per-vertex as a linear interpolation between the lit vertex
// color and a fog color, based on the vertex's view-space depth (distance
// along the camera's forward axis, NOT euclidian distance from the camera).
//
// The real per-vertex fog application (model space vertices to world space,
// view_depth calculation, and calling these helpers) is in render.odin's
// _draw_command_lit so it can rely on the cached camera state. Later we'll
// make it support a 1D fog ramp LUT sampled by view_depth for full
// artistic control when the texture system lands (like if you wanna make a
// pink sunset fog)

// Fog_Settings

Fog_Settings :: struct {
	enabled: bool,
	color:   rmath.Vec3,
	near:    f32,
	far:     f32,
}

DEFAULT_FOG :: Fog_Settings {
	enabled = false,
	color   = {0.5, 0.55, 0.65}, // cool grayish blue
	near    = 20.0,
	far     = 60.0,
}

// Helpers

// Returns fog factor in [0, 1]. 0 = no fog, 1 = fully fogged
compute_fog_factor :: #force_inline proc(fog: Fog_Settings, view_depth: f32) -> f32 {
	if !fog.enabled do return 0
	if fog.far <= fog.near do return 0

	t := (view_depth - fog.near) / (fog.far - fog.near)
	if t < 0 do return 0
	if t > 1 do return 1
	return t
}

// Lerps `lit` toward `fog_color` by `fog_factor`
apply_fog :: #force_inline proc(
	lit: rmath.Vec3,
	fog_color: rmath.Vec3,
	fog_factor: f32,
) -> rmath.Vec3 {
	inv := 1.0 - fog_factor
	return rmath.Vec3 {
		x = lit.x * inv + fog_color.x * fog_factor,
		y = lit.y * inv + fog_color.y * fog_factor,
		z = lit.z * inv + fog_color.z * fog_factor,
	}
}
