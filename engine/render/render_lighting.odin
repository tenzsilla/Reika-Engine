package render

import "../rmath"

// Reika lighting -- PS1 style vertex lighting
//
// Lighting is a first class system but it's minimal and explicit for now.
// The initial implementation is a single directional light with Lambert
// diffuse + ambient, computed per vertex. There are three lighting models
// currently supported:
//
// 		.Flat 	 -- ambient only and no diffuse
// 		.Lambert -- smooth Lambert diffuse + ambient
// 		.Toon    -- step ramp diffuse + ambient
//
// Future extensions:
// 		- point lights (limited count, simple attenuation)
// 		- 1D LUT based stylized lighting curves for full artistic control
// 		- and an optional simple specular (non PBR)
//
// This file is grouped separately so that a future split into its own
// `render_light` package is easy

// Lighting model

Lighting_Model :: enum {
	Flat,
	Lambert,
	Toon,
}

// Directional light

Directional_Light :: struct {
	direction: rmath.Vec3,
	color:     rmath.Vec3,
	intensity: f32,
	ambient:   rmath.Vec3,
}

DEFAULT_DIRECTIONAL_LIGHT :: Directional_Light {
	direction = {0.5, -1.0, 0.3}, // sun from the upper right
	color     = {1.0, 1.0, 1.0},
	intensity = 1.0,
	ambient   = {0.2, 0.2, 0.25},
}

// Per vertex lighting (on the CPU)

vertex_light_color :: #force_inline proc(
	normal: rmath.Vec3,
	light: Directional_Light,
	tint: rmath.Vec3 = rmath.Vec3{1, 1, 1},
	baked: rmath.Vec3 = rmath.Vec3{1, 1, 1},
	model: Lighting_Model = .Lambert,
) -> rmath.Vec3 {
	neg_l := rmath.Vec3 {
		x = -light.direction.x,
		y = -light.direction.y,
		z = -light.direction.z,
	}

	ndotl := rmath.vec3_dot(normal, neg_l)

	// Quantize N dot L
	diffuse_factor: f32
	switch model {
	case .Flat:
		diffuse_factor = 0
	case .Lambert:
		if ndotl < 0 do ndotl = 0
		diffuse_factor = ndotl
	case .Toon:
		// 3 band step ramp (shadow / mid / lit)
		// If we want to soften then we swap to a 1D LUT later
		if ndotl < 0 {
			diffuse_factor = 0
		} else if ndotl < 0.5 {
			diffuse_factor = 0.5
		} else {
			diffuse_factor = 1.0
		}
	}

	return rmath.Vec3 {
		x = (light.ambient.x + light.color.x * light.intensity * diffuse_factor) *
		baked.x *
		tint.x,
		y = (light.ambient.y + light.color.y * light.intensity * diffuse_factor) *
		baked.y *
		tint.y,
		z = (light.ambient.z + light.color.z * light.intensity * diffuse_factor) *
		baked.z *
		tint.z,
	}
}
