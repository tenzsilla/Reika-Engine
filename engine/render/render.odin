package render

import "../core"
import "../rmath"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Reika renderer
//
// Modern raylib/OpenGL backend intentionally reproducing the PS2-era
// visual language with: vertex dominant CPU lighting, single directional
// light, flat render command pipeline. The renderer consumes pre-built
// render commands and never queries ECS or any gameplay state directly
//
// The renderer owns the camera state, directional light state, built-in
// unit cube geometry. Though the renderer does NOT own the command slice
// (the caller owns it, while the renderer reads only), ECS state, and
// gameplay state.
//
// Raylib types never leave this package. Reika math types are the public
// API; conversion to rl.* happens internally with transmuting (layout
// compatible by design, see rmath/math.odin)

// Public types

// Render_Command is the unit of work the renderer consumes per draw
Render_Command :: struct {
	mesh_id:   u32,
	transform: rmath.Mat4,
}

Camera_Projection :: enum {
	Perspective,
	Orthographic,
}

// Camera uses Reika math only and is converted to rl.Camera3D internally
Camera :: struct {
	position:   rmath.Vec3,
	target:     rmath.Vec3,
	up:         rmath.Vec3,
	fovy:       f32, // vertical FOV in degrees (perspective only)
	projection: Camera_Projection,
}

DEFAULT_CAMERA :: Camera {
	position   = {5, 5, 5},
	target     = {0, 0, 0},
	up         = {0, 1, 0},
	fovy       = 60.0,
	projection = .Perspective,
}

// Renderer private state

@(private)
g_camera: Camera = DEFAULT_CAMERA

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
	g_camera = DEFAULT_CAMERA
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

set_camera :: proc(cam: Camera) {
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
	rl_cam := _to_rl_camera(g_camera)

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
	// mesh_id is ignored for now and only the built in cube exists
	// Asset pipeline will resolve mesh_id to a geometry source

	for i in 0 ..< CUBE_INDEX_COUNT {
		idx := g_cube_indices[i]
		model_pos := g_cube_positions[idx]
		model_normal := g_cube_normals[idx]

		world_pos := rmath.mat4_transform_point(cmd.transform, model_pos)

		// mat4_transform_dir applies the rotation+scale portion
		// (drops translation). For uniform scale this is fine but
		// for non uniform scale, normals would need the inverse
		// transpose. It's acceptable for the current scope we have
		// but we'll revisit when art direction requires non uniform
		// scaled meshes with correct lighting
		world_normal := rmath.vec3_normalize(rmath.mat4_transform_dir(cmd.transform, model_normal))

		r, g, b, a := vertex_light_color(world_normal, g_light)
		rlgl.Color4ub(r, g, b, a)
		rlgl.Vertex3f(world_pos.x, world_pos.y, world_pos.z)
	}
}

// Raylib conversion (private)
//
// transmute is valid here because Reika's Vec3 and rl.Vector3 are both
// {x, y, z: f32} with no padding

@(private)
_to_rl_camera :: proc(cam: Camera) -> rl.Camera3D {
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
