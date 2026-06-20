package game

import cam "../engine/camera"
import "../engine/core"
import "../engine/ecs"
import "../engine/input"
import "../engine/profiler"
import "../engine/render"
import "../engine/rmath"
import "core:fmt"
import "core:math"

// Stress test scene: 100 spinning tinted cubes in a 10x10 grid
//
// The profiler overlay (F1 to toggle) shows FPS + frame ms + fixed step
// count so we can see the cost live

CUBE_COUNT :: 1000
GRID_SIDE :: 32
GRID_SPACING :: f32(2.0)

// Game_State holds all runtime gameplay data
Game_State :: struct {
	initialized:      bool,

	// Camera is game owned authoritative state
	camera:           cam.Camera,
	// free fly debug camera controller
	cam_ctrl:         cam.Camera_Controller,

	// Cube entity handles
	cube_entities:    [CUBE_COUNT]ecs.Entity,
	cube_spin_speeds: [CUBE_COUNT]f32,
	cube_angles:      [CUBE_COUNT]f32,
	show_profiler:    bool,
}

@(private)
g_state: Game_State

// 1024 is alright for now
MAX_GAME_RENDER_COMMANDS :: 1024

// Register wires the game hooks into the engine
register :: proc() {
	core.set_hooks(
		{
			on_init = on_init,
			on_fixed_update = on_fixed_update,
			on_render = on_render,
			on_shutdown = on_shutdown,
		},
	)
}

@(private)
on_init :: proc() {
	g_state = {}
	g_state.initialized = true
	g_state.show_profiler = true

	// renderer borrows a pointer to it
	g_state.camera = cam.DEFAULT_CAMERA
	g_state.camera.position = {20, 18, 20}
	g_state.camera.target = {0, 0, 0}
	render.set_camera_ptr(&g_state.camera)

	// wire the controller to the camera
	g_state.cam_ctrl = cam.camera_controller_init(&g_state.camera)

	render.set_directional_light(render.DEFAULT_DIRECTIONAL_LIGHT)

	_spawn_cubes()

	core.log_info("Game initialized - %d cubes spawned", CUBE_COUNT)
}

// Spawn CUBE_COUNT cubes in a GRID_SIDE * GRID_SIDE grid
@(private)
_spawn_cubes :: proc() {
	half := f32(GRID_SIDE - 1) * 0.5

	for i in 0 ..< CUBE_COUNT {
		gx := i % GRID_SIDE
		gz := i / GRID_SIDE

		pos := rmath.Vec3 {
			x = (f32(gx) - half) * GRID_SPACING,
			y = 0,
			z = (f32(gz) - half) * GRID_SPACING,
		}

		tint := _hash_tint(i)
		spin := _hash_spin_speed(i)

		e := ecs.entity_create()
		if e == ecs.ENTITY_INVALID {
			core.log_error("Game: failed to allocate cube entity %d", i)
			continue
		}

		ecs.transform_add(
			e,
			rmath.Transform{position = pos, rotation = rmath.QUAT_IDENTITY, scale = {1, 1, 1}},
		)
		ecs.mesh_renderer_add(e, 0, 0, tint)

		g_state.cube_entities[i] = e
		g_state.cube_spin_speeds[i] = spin
		g_state.cube_angles[i] = 0
	}
}

// Deterministic tint generator
@(private)
_hash_tint :: proc(i: int) -> rmath.Vec3 {
	fi := f64(i)
	r := 0.55 + 0.45 * math.sin(fi * 1.7)
	g := 0.55 + 0.45 * math.sin(fi * 2.3 + 1.0)
	b := 0.55 + 0.45 * math.sin(fi * 3.1 + 2.0)
	return rmath.Vec3{x = f32(r), y = f32(g), z = f32(b)}
}

// Deterministic spin speed in deg/s
@(private)
_hash_spin_speed :: proc(i: int) -> f32 {
	fi := f64(i)
	v := 60.0 + 40.0 * math.sin(fi * 5.7)
	if math.sin(fi * 1.1) > 0 do v = -v
	return f32(v)
}

@(private)
on_fixed_update :: proc(dt: f32) {
	snap := input.get()

	// Quit on escape
	if snap.keys.escape_pressed {
		core.request_quit()
		return
	}

	// F1 toggles profiler overlay
	if snap.keys.f1_pressed {
		g_state.show_profiler = !g_state.show_profiler
	}

	// Spin every cube around its local y axis
	for i in 0 ..< CUBE_COUNT {
		e := g_state.cube_entities[i]
		if e == ecs.ENTITY_INVALID do continue

		g_state.cube_angles[i] += g_state.cube_spin_speeds[i] * dt
		t := ecs.transform_get(e)
		if t == nil do continue

		t.rotation = rmath.quat_from_axis_angle_rad(
			rmath.VEC3_UP,
			rmath.deg_to_rad(g_state.cube_angles[i]),
		)
	}
}

@(private)
on_render :: proc(dt: f32) {
	// update the debug cam from input
	cam.camera_controller_update(&g_state.cam_ctrl, dt)

	render.begin_frame()
	defer render.end_frame()

	arena := core.mem_frame()
	cmds := core.arena_push_slice(
		arena,
		render.Render_Command,
		MAX_GAME_RENDER_COMMANDS,
		"game_render_cmds",
	)
	if cmds == nil {
		core.log_error("game.on_render: failed to allocate render command buffer")
		return
	}

	count := _build_render_commands(cmds)
	render.submit(cmds[:count])

	if g_state.show_profiler {
		_draw_profiler_overlay()
	}
}

// Builds render commands from ECS component arrays
// Only iterates live entity slots with ecs.live_indices() -> O(live_count)
@(private)
_build_render_commands :: proc(cmds: []render.Render_Command) -> int {
	transforms, has_t := ecs.transforms_raw()
	mesh_renderers, has_mr := ecs.mesh_renderers_raw()
	live := ecs.live_indices()

	count := 0
	cap := len(cmds)

	for i in 0 ..< len(live) {
		if count >= cap do break
		idx := int(live[i])
		if !has_mr[idx] do continue
		if !has_t[idx] do continue
		if !mesh_renderers[idx].visible do continue

		cmds[count] = render.Render_Command {
			mesh_id   = mesh_renderers[idx].mesh_id,
			transform = rmath.transform_to_mat4(transforms[idx]),
			tint      = mesh_renderers[idx].tint,
		}
		count += 1
	}

	return count
}

// Draws a small profiler hud in the top-left corner
@(private)
_draw_profiler_overlay :: proc() {
	snap := profiler.get_snapshot()

	buf: [128]u8
	text := fmt.bprintf(
		buf[:],
		"FPS: %.1f  Frame: %.2f ms\nFixed steps: %.2f avg  (cubes: %d)",
		snap.fps,
		snap.frame_ms,
		snap.fixed_steps,
		CUBE_COUNT,
	)

	if len(text) < len(buf) {
		buf[len(text)] = 0
	}

	cstr := cast(cstring)&buf[0]

	// Drop shadow for readability
	render.draw_text(cstr, 9, 9, 20, render.COLOR_BLACK_SHADOW)
	render.draw_text(cstr, 8, 8, 20, render.COLOR_WHITE)
}

@(private)
on_shutdown :: proc() {
	core.log_info("Game shutdown")
}
