package game

import "../engine/core"
import "../engine/input"

// Game_State holds all runtime gameplay data
Game_State :: struct {
	initialized: bool,
}

@(private)
g_state: Game_State

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
}

@(private)
on_render :: proc(dt: f32) {
	// Rendering will be here
}

@(private)
on_shutdown :: proc() {
	core.log_info("Game shutdown")
}
