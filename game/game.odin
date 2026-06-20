package game

import cam "../engine/camera"
import "../engine/core"
import "../engine/ecs"
import "../engine/input"
import "../engine/render"
import "../engine/rmath"

// Game_State holds all runtime gameplay data
Game_State :: struct {
	initialized: bool,

	// Camera is game owned authoritative state
	camera:      cam.Camera,

	// free fly debug camera controller
	cam_ctrl:    cam.Camera_Controller,

	// test entity
	test_entity: ecs.Entity,
	test_angle:  f32,
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

	// renderer borrows a pointer to it
	g_state.camera = cam.DEFAULT_CAMERA
	render.set_camera_ptr(&g_state.camera)

	// wire the controller to the camera
	g_state.cam_ctrl = cam.camera_controller_init(&g_state.camera)

	render.set_directional_light(render.DEFAULT_DIRECTIONAL_LIGHT)

	e := ecs.entity_create()
	if e != ecs.ENTITY_INVALID {
		ecs.transform_add(
			e,
			rmath.Transform {
				position = {0, 0, 0},
				rotation = rmath.QUAT_IDENTITY,
				scale = {1, 1, 1},
			},
		)
		ecs.mesh_renderer_add(e, 0, 0) // mesh_id 0 = built in cube
		g_state.test_entity = e
	}

	core.log_info("Game initialized")
}

@(private)
on_fixed_update :: proc(dt: f32) {
	snap := input.get()

	// Quit on escape
	if snap.keys.escape_pressed {
		core.request_quit()
		return
	}

	// Slowly rotate the test cube
	if g_state.test_entity != ecs.ENTITY_INVALID {
		g_state.test_angle += 30.0 * dt // 30 deg/s around Y
		t := ecs.transform_get(g_state.test_entity)
		if t != nil {
			t.rotation = rmath.quat_from_axis_angle_rad(
				rmath.VEC3_UP,
				rmath.deg_to_rad(g_state.test_angle),
			)
		}
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
}

// Builds render commands from ECS component arrays
@(private)
_build_render_commands :: proc(cmds: []render.Render_Command) -> int {
	transforms, has_t := ecs.transforms_raw()
	mesh_renderers, has_mr := ecs.mesh_renderers_raw()

	count := 0
	cap := len(cmds)

	for i in 0 ..< ecs.MAX_ENTITIES {
		if count >= cap do break
		if !has_mr[i] do continue
		if !has_t[i] do continue
		if !mesh_renderers[i].visible do continue

		cmds[count] = render.Render_Command {
			mesh_id   = mesh_renderers[i].mesh_id,
			transform = rmath.transform_to_mat4(transforms[i]),
		}
		count += 1
	}

	return count
}

@(private)
on_shutdown :: proc() {
	core.log_info("Game shutdown")
}
