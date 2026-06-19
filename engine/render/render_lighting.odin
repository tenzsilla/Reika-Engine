package render

import "../rmath"

// Reika lighting -- PS2 style vertex lighting
//
// Lighting is a first class system but it's minimal and explicit for now.
// The initial implementation is a single directional light with Lambert
// diffuse + ambient, computed per vertex on CPU. This reproduces the
// baseline ps2 vertex lighting dominant look thingy
//
// Future extensions:
// 		- point lights (limited count, simple attenuation)
// 		- baked lighting / lightmaps (offline baked into vertex colors or
// 		  a separate attribute stream)
// 		- ramp based / stylized lighting curves (1D LUT sampled by N·L)
// 		- and an optional simple specular (non PBR)
//
// This file is grouped separately so that a future split into its own
// `render_light` package is easy

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

vertex_light_color :: proc(normal: rmath.Vec3, light: Directional_Light) -> (r, g, b, a: u8) {
	neg_l := rmath.Vec3 {
		x = -light.direction.x,
		y = -light.direction.y,
		z = -light.direction.z,
	}

	ndotl := rmath.vec3_dot(normal, neg_l)
	if ndotl < 0 do ndotl = 0

	lit := rmath.Vec3 {
		x = light.ambient.x + light.color.x * light.intensity * ndotl,
		y = light.ambient.y + light.color.y * light.intensity * ndotl,
		z = light.ambient.z + light.color.z * light.intensity * ndotl,
	}

	r = u8(rmath.clamp(lit.x, 0.0, 1.0) * 255.0 + 0.5)
	g = u8(rmath.clamp(lit.y, 0.0, 1.0) * 255.0 + 0.5)
	b = u8(rmath.clamp(lit.z, 0.0, 1.0) * 255.0 + 0.5)
	a = 255
	return
}
