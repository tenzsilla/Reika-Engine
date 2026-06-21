package render

import cam "../camera"
import "../core"
import "../rmath"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Reika renderer
//
// The late PS1 look of this type of rendering approach has a certain low
// resolution visual style created by using techniques such as 3D upscaling
// with vertex snapping, toon lighting, per-vertex colors/fog and NEAREST
// texture filtering. It uses an on_render hook from the game and follows
// a strict lifecycle contract (begin_frame -> submit commands -> end_frame)
// and encapsulates all 3D rendering that is done in a sub-resolution
// framebuffer with a second, native draw pass for the 2D UI drawing at
// native full screen resolution. Architecturally, it enforces strict
// boundaries; since all Raylib types are encapsulated internally, a clean
// API is exposed with layout compatible Reika math types, and gameplay,
// input, fog, framebuffer state and native cube geometry; whereas camera
// matrices material structures and command slices exist as read-only or
// borrowed dependencies.

// Public types

// Filter_Mode controls GPU texture sampling
Filter_Mode :: enum {
	Nearest, // ps1 default
	Bilinear, // modern
}

// Fog_Response controls whether per-vertex fog is applied to a draw
Fog_Response :: enum {
	Affected, // Vertex colors lerped toward fog color
	Unaffected, // Fog skipped for this draw
}

// Texture_Handle is an opaque handle into the renderer's texture storage
Texture_Handle :: distinct u32
TEXTURE_INVALID :: Texture_Handle(0)

// Render_Command is the unit of work the renderer consumes per draw
Render_Command :: struct {
	mesh_id:      u32,
	transform:    rmath.Mat4,
	tint:         rmath.Vec3,
	texture:      Texture_Handle,
	filter:       Filter_Mode,
	lighting:     Lighting_Model,
	fog_response: Fog_Response,
	vertex_snap:  bool,
	affine_uv:    bool,
	dither:       bool,
}

// Camera types (Camera, Camera_Projection, DEFAULT_CAMERA) and the
// camera_*_matrix procs are in the `camera` package

// Renderer private state

@(private)
g_camera: ^cam.Camera = nil

@(private)
g_light: Directional_Light

@(private)
g_bg_color: rl.Color = rl.Color{30, 30, 40, 255}

@(private)
g_fog: Fog_Settings

// Cached camera state, recalculated once per submit() call
@(private)
g_cam_cache: struct {
	pos:     rmath.Vec3,
	forward: rmath.Vec3,
}

// PS1 low-res framebuffer state
@(private)
PS1_Lowres_State :: struct {
	enabled:      bool,
	width:        i32,
	height:       i32,
	target:       rl.RenderTexture2D,
	target_valid: bool,
}

@(private)
g_ps1: PS1_Lowres_State

// Texture storage with a fixed capacity array of rl.Texture2D
// Full asset pipeline will replace this with a proper registry later
MAX_TEXTURES :: 256

@(private)
g_textures: [MAX_TEXTURES]rl.Texture2D

@(private)
g_texture_count: int = 0

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
g_cube_colors: [CUBE_VERTEX_COUNT]rmath.Vec3 = {
	// +x face
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	// -x face
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	// +y face
	{1.00, 1.00, 1.00},
	{1.00, 1.00, 1.00},
	{1.00, 1.00, 1.00},
	{1.00, 1.00, 1.00},
	// -y face
	{0.60, 0.60, 0.60},
	{0.60, 0.60, 0.60},
	{0.60, 0.60, 0.60},
	{0.60, 0.60, 0.60},
	// +z face
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	// -z face
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
	{0.85, 0.85, 0.85},
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
	g_fog = DEFAULT_FOG
	g_ps1 = {
		enabled      = false,
		width        = 320,
		height       = 240,
		target_valid = false,
	}
	g_texture_count = 0

	core.log_info(
		"Renderer ready - light dir <%.2f, %.2f, %.2f>, fog enabled: %v",
		g_light.direction.x,
		g_light.direction.y,
		g_light.direction.z,
		g_fog.enabled,
	)
}

shutdown :: proc() {
	if g_ps1.target_valid {
		rl.UnloadRenderTexture(g_ps1.target)
		g_ps1.target_valid = false
	}
	_texture_unload_all()

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

// Sets the active fog settings
set_fog :: proc(fog: Fog_Settings) {
	g_fog = fog
}

get_fog :: proc() -> Fog_Settings {
	return g_fog
}

// Enables/disables ps1 low res framebuffer mode
set_ps1_lowres :: proc(enabled: bool, width: i32 = 320, height: i32 = 240) {
	if enabled && !g_ps1.target_valid {
		g_ps1.target = rl.LoadRenderTexture(width, height)
		rl.SetTextureFilter(g_ps1.target.texture, .POINT)
		g_ps1.target_valid = true
		g_ps1.width = width
		g_ps1.height = height
		core.log_info("PS1 low-res FB allocated: %dx%d", width, height)
	}
	g_ps1.enabled = enabled
}

is_ps1_lowres :: proc() -> bool {
	return g_ps1.enabled
}

// Texture loading (full asset pipeline for later)

texture_load :: proc(path: cstring) -> Texture_Handle {
	if g_texture_count >= MAX_TEXTURES {
		core.log_error(
			"render.texture_load: texture slot exhausted (MAX_TEXTURES=%d)",
			MAX_TEXTURES,
		)
		return TEXTURE_INVALID
	}
	tex := rl.LoadTexture(path)
	if tex.id == 0 {
		core.log_error("render.texture_load: rl.LoadTexture failed for '%s'", path)
		return TEXTURE_INVALID
	}
	idx := g_texture_count
	g_textures[idx] = tex
	g_texture_count += 1
	return Texture_Handle(idx + 1)
}

texture_get :: proc(handle: Texture_Handle) -> ^rl.Texture2D {
	if handle == TEXTURE_INVALID do return nil
	idx := int(handle) - 1
	if idx < 0 || idx >= g_texture_count do return nil
	return &g_textures[idx]
}

@(private)
_texture_unload_all :: proc() {
	for i in 0 ..< g_texture_count {
		rl.UnloadTexture(g_textures[i])
	}
	g_texture_count = 0
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
// The Render_Commands submitted to the vertex batch are prebuilt and will
// be drawn in one batch of rlgl.Begin(rlgl.TRIANGLES) / rlgl.End(). The
// CPU is also responsible for doing per vertex lighting (like PS1) based
// on the model space light path: the light direction is transformed into
// model space per cube (only once), and then for each vertex, N dot L is
// calculated from the model space light - essentially the shader does the
// normal and light calculations. The actual vertex positions emitted to
// the vertex array are in model space, and the gpu will do any necessary
// world transformation using the rlgl matrix stack

submit :: proc(commands: []Render_Command) {
	if g_camera == nil {
		core.log_error(
			"render.submit() called with no camera set; call set_camera_ptr() during init",
		)
		return
	}

	_update_camera_cache()

	using_fbo := g_ps1.enabled && g_ps1.target_valid
	if using_fbo {
		rl.BeginTextureMode(g_ps1.target)
		rl.ClearBackground(g_bg_color)
	}

	rl_cam := _to_rl_camera(g_camera^)
	rl.BeginMode3D(rl_cam)

	rlgl.Begin(rlgl.TRIANGLES)

	for cmd in commands {
		_draw_command_lit(cmd)
	}

	rlgl.End()

	rl.EndMode3D()

	if using_fbo {
		rl.EndTextureMode()

		// blit fb to screen with nearest upscale
		source := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = f32(g_ps1.target.texture.width),
			height = -f32(g_ps1.target.texture.height),
		}
		dest := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = f32(rl.GetScreenWidth()),
			height = f32(rl.GetScreenHeight()),
		}
		rl.DrawTexturePro(g_ps1.target.texture, source, dest, rl.Vector2{0, 0}, 0.0, rl.WHITE)
	}
}

@(private)
_draw_command_lit :: proc(cmd: Render_Command) {
	// GPU transform + model space CPU lighting
	//
	// Sooo... to improve performance, the light direction in world
	// coordinates is converted to model coordinates only once per cube
	// using a logical use of data as opposed to performing per vertex CPU
	// based matrix calculations on the lighting. The conversion to world
	// coordinate for each vertex is only executed if the fog is on;
	// otherwise no conversion will occur. Presently the mesh_id has been
	// disabled in favor of using a built-in cube and the classic PS1
	// effect flags (vertex_snap, affine_uv, dither) are only beign used
	// as temporary placeholders that will be fully implemented in future
	// pipeline updates
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

	fog_active := cmd.fog_response == .Affected && g_fog.enabled

	packed: [CUBE_VERTEX_COUNT][4]u8
	for v in 0 ..< CUBE_VERTEX_COUNT {
		lit := vertex_light_color(
			g_cube_normals[v],
			model_light,
			cmd.tint,
			g_cube_colors[v],
			cmd.lighting,
		)

		if fog_active {
			world_pos := rmath.mat4_transform_point(cmd.transform, g_cube_positions[v])
			rel := rmath.vec3_sub(world_pos, g_cam_cache.pos)
			view_depth := rmath.vec3_dot(rel, g_cam_cache.forward)
			factor := compute_fog_factor(g_fog, view_depth)
			lit = apply_fog(lit, g_fog.color, factor)
		}

		packed[v] = {
			u8(rmath.clamp(lit.x, 0.0, 1.0) * 255.0 + 0.5),
			u8(rmath.clamp(lit.y, 0.0, 1.0) * 255.0 + 0.5),
			u8(rmath.clamp(lit.z, 0.0, 1.0) * 255.0 + 0.5),
			255,
		}
	}

	rlgl.PushMatrix()
	mat := cmd.transform.m
	rlgl.MultMatrixf(cast([^]f32)&mat[0])

	for i in 0 ..< CUBE_INDEX_COUNT {
		idx := g_cube_indices[i]
		c := packed[idx]
		rlgl.Color4ub(c[0], c[1], c[2], c[3])
		p := g_cube_positions[idx]
		rlgl.Vertex3f(p.x, p.y, p.z) // model space
	}

	rlgl.PopMatrix()
}

@(private)
_update_camera_cache :: proc() {
	if g_camera == nil do return
	g_cam_cache.pos = g_camera.position
	diff := rmath.vec3_sub(g_camera.target, g_camera.position)
	g_cam_cache.forward = rmath.vec3_normalize(diff)
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
