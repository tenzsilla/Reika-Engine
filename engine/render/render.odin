package render

import cam "../camera"
import "../core"
import "../rmath"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Reika renderer
//
// Modern raylib/OpenGL backend intentionally reproducing the PS2-era
// visual language with: vertex dominant CPU lighting, single directional
// light, flat render command pipeline. The renderer consumes pre-built
// render commands and never queries ECS, gameplay or any input state directly
//
// Renderer owns the directional light state, the built in unit cube geometry,
// and a borrowed pointer to a game owned Camera. Renderer however does not own
// the camera storage, the command slice (the caller owns and renderer reads only),
// ECS state, gameplay state, input state.
//
// Raylib types never leave this package. Reika math types are the public
// API; conversion to rl.* happens internally with transmuting (layout
// compatible by design, see rmath/math.odin)

// Public types

// Render_Command is the unit of work the renderer consumes per draw
Render_Command :: struct {
	mesh_id:   u32,
	transform: rmath.Mat4,
	tint:      rmath.Vec3,
}

// Renderer private state

@(private)
g_camera: ^cam.Camera = nil

@(private)
g_light: Directional_Light

@(private)
g_bg_color: rl.Color = rl.Color{30, 30, 40, 255}

// Built in unit cube
//
// 24 vertices and 36 indices (12 triangles)
// Winding is CCW from outside (which matches raylib's default front face)
// Stored as package level constants
//
// When the asset pipeline is gonna be done, this becomes the fallback for
// mesh_id == 0 and other meshes are resolved through the asset module

CUBE_VERTEX_COUNT :: 24
CUBE_INDEX_COUNT :: 36

@(private)
g_cube_positions: [CUBE_VERTEX_COUNT]rmath.Vec3 = {
	// +x face
	{0.5, -0.5, -0.5},
	{0.5, 0.5, -0.5},
	{0.5, 0.5, 0.5},
	{0.5, -0.5, 0.5},
	// -x face
	{-0.5, -0.5, 0.5},
	{-0.5, 0.5, 0.5},
	{-0.5, 0.5, -0.5},
	{-0.5, -0.5, -0.5},
	// +y face
	{-0.5, 0.5, -0.5},
	{-0.5, 0.5, 0.5},
	{0.5, 0.5, 0.5},
	{0.5, 0.5, -0.5},
	// -y face
	{-0.5, -0.5, 0.5},
	{-0.5, -0.5, -0.5},
	{0.5, -0.5, -0.5},
	{0.5, -0.5, 0.5},
	// +z face
	{-0.5, -0.5, 0.5},
	{0.5, -0.5, 0.5},
	{0.5, 0.5, 0.5},
	{-0.5, 0.5, 0.5},
	// -z face
	{0.5, -0.5, -0.5},
	{-0.5, -0.5, -0.5},
	{-0.5, 0.5, -0.5},
	{0.5, 0.5, -0.5},
}

@(private)
g_cube_normals: [CUBE_VERTEX_COUNT]rmath.Vec3 = {
	{1, 0, 0},
	{1, 0, 0},
	{1, 0, 0},
	{1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{-1, 0, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, 1, 0},
	{0, -1, 0},
	{0, -1, 0},
	{0, -1, 0},
	{0, -1, 0},
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, 1},
	{0, 0, -1},
	{0, 0, -1},
	{0, 0, -1},
	{0, 0, -1},
}

@(private)
g_cube_indices: [CUBE_INDEX_COUNT]u32 = {
	// +x
	0,
	1,
	2,
	0,
	2,
	3,
	// -x
	4,
	5,
	6,
	4,
	6,
	7,
	// +y
	8,
	9,
	10,
	8,
	10,
	11,
	// -y
	12,
	13,
	14,
	12,
	14,
	15,
	// +z
	16,
	17,
	18,
	16,
	18,
	19,
	// -z
	20,
	21,
	22,
	20,
	22,
	23,
}

// Lifecycle

init :: proc() {
	g_camera = nil
	g_light = DEFAULT_DIRECTIONAL_LIGHT
	g_light.direction = rmath.vec3_normalize(g_light.direction)

	core.log_info(
		"Renderer ready - light dir <%.2f, %.2f, %.2f>, color <%.2f, %.2f, %.2f>",
		g_light.direction.x,
		g_light.direction.y,
		g_light.direction.z,
		g_light.color.x,
		g_light.color.y,
		g_light.color.z,
	)
}

shutdown :: proc() {
	core.log_info("Renderer shutdown")
}

// Setters

set_camera_ptr :: proc(cam: ^cam.Camera) {
	g_camera = cam
}

// Sets the active directional light
// Subsequent lighting math assumes unit length
set_directional_light :: proc(light: Directional_Light) {
	l := light
	l.direction = rmath.vec3_normalize(l.direction)
	g_light = l
}

set_background_color :: proc(r, g, b: u8) {
	g_bg_color = rl.Color{r, g, b, 255}
}

// Color helpers

Color :: rl.Color

make_color :: proc(r, g, b, a: u8) -> Color {
	return Color{r, g, b, a}
}

COLOR_WHITE :: Color{255, 255, 255, 255}
COLOR_BLACK :: Color{0, 0, 0, 255}
COLOR_BLACK_SHADOW :: Color{0, 0, 0, 180}

// 2D text overlay (used by the game layer to draw the profiler / debug HUD)

draw_text :: proc(text: cstring, x: i32, y: i32, size: i32, color: Color) {
	rl.DrawText(text, x, y, size, color)
}

draw_text_default :: proc(text: cstring, x: i32, y: i32) {
	rl.DrawText(text, x, y, 20, COLOR_WHITE)
}

// Frame
//
// begin_frame/end_frame bracket the entire frame's drawing (raylib
// BeginDrawing/EndDrawing). submit() owns the 3d camera mode bracket so
// the game can alternate 2D ui passes between submit() and end_frame()
// without re-entering 3D mode

begin_frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(g_bg_color)
}

end_frame :: proc() {
	rl.EndDrawing()
}

// Submission
//
// Enters 3d camera mode, then batches all commands into a single rlgl
// triangle draw. Per vertex lighting is computed on cpu (ps2 style
// For each vertex, transform the model space normal into world space,
// dot against the negated light direction (lambert), and push a
// (color, position) pair to rlgl

submit :: proc(commands: []Render_Command) {
	if g_camera == nil {
		core.log_error(
			"render.submit() called with no camera set; call set_camera_ptr() during init",
		)
		return
	}

	rl_cam := _to_rl_camera(g_camera^)
	rl.BeginMode3D(rl_cam)
	defer rl.EndMode3D()

	rlgl.Begin(rlgl.TRIANGLES)

	for cmd in commands {
		_draw_command_lit(cmd)
	}

	rlgl.End()
}

@(private)
_draw_command_lit :: proc(cmd: Render_Command) {
	// GPU transform + model space CPU lighting
	//
	// The world space light direction is transformed into model space
	// ONCE per cube (which is cheap because it's one transpose + one
	// transform_dir + one normalize). Then per vertex lighting is
	// computed in model space using the precomputed model normals
	transform_t := rmath.mat4_transpose(cmd.transform)
	model_light_dir := rmath.vec3_normalize(
		rmath.mat4_transform_dir(transform_t, g_light.direction),
	)

	model_light := Directional_Light {
		direction = model_light_dir,
		color     = g_light.color,
		intensity = g_light.intensity,
		ambient   = g_light.ambient,
	}

	lit_colors: [CUBE_VERTEX_COUNT][4]u8
	for v in 0 ..< CUBE_VERTEX_COUNT {
		r, g, b, a := vertex_light_color(g_cube_normals[v], model_light, cmd.tint)
		lit_colors[v] = {r, g, b, a}
	}

	rlgl.PushMatrix()
	mat := cmd.transform.m
	rlgl.MultMatrixf(cast([^]f32)&mat[0])

	for i in 0 ..< CUBE_INDEX_COUNT {
		idx := g_cube_indices[i]
		c := lit_colors[idx]
		rlgl.Color4ub(c[0], c[1], c[2], c[3])
		p := g_cube_positions[idx]
		rlgl.Vertex3f(p.x, p.y, p.z) // model space
	}

	rlgl.PopMatrix()
}

// Raylib conversion (private)
//
// transmute is valid here because Reika's Vec3 and rl.Vector3 are both
// {x, y, z: f32} with no padding

@(private)
_to_rl_camera :: proc(cam: cam.Camera) -> rl.Camera3D {
	rl_proj: rl.CameraProjection
	switch cam.projection {
	case .Perspective:
		rl_proj = .PERSPECTIVE
	case .Orthographic:
		rl_proj = .ORTHOGRAPHIC
	}

	return rl.Camera3D {
		position = transmute(rl.Vector3)cam.position,
		target = transmute(rl.Vector3)cam.target,
		up = transmute(rl.Vector3)cam.up,
		fovy = cam.fovy,
		projection = rl_proj,
	}
}
