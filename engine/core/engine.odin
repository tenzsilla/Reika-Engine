package core

import input "../input"
import rl "vendor:raylib"

Engine_Config :: struct {
	window_title:  cstring,
	window_width:  i32,
	window_height: i32,
	target_fps:    i32,
	log_level:     Log_Level,
	memory:        Memory_Config,
}

DEFAULT_CONFIG :: Engine_Config {
	window_title  = "Reika",
	window_width  = 1280,
	window_height = 720,
	target_fps    = 180,
	log_level     = .Info,
	memory        = DEFAULT_MEMORY_CONFIG,
}

@(private)
g_running: bool

// Function pointers for the game layer to hook into the engine loop
// Set by the game layer before core.init() returns, or with core.set_hooks()
Game_Hooks :: struct {
	// Called once after engine systems are ready
	on_init:         proc(),
	// Called once per fixed step, dt is always FIXED_DELTA_TIME
	on_fixed_update: proc(dt: f32),
	// Called once per rendered frame, dt is real frame delta
	on_render:       proc(dt: f32),
	// Called once before engine shutdown
	on_shutdown:     proc(),
}

@(private)
g_hooks: Game_Hooks

set_hooks :: proc(hooks: Game_Hooks) {
	g_hooks = hooks
}

init :: proc(config: Engine_Config = DEFAULT_CONFIG) {
	log_set_level(config.log_level)
	log_info(
		"Reika engine init - %dx%d @fixed %dHz",
		config.window_width,
		config.window_height,
		FIXED_UPDATE_HZ,
	)

	if !memory_init(config.memory) {
		log_error("Engine init failed: memory allocation error")
		return
	}

	rl.InitWindow(config.window_width, config.window_height, config.window_title)

	if config.target_fps > 0 {
		rl.SetTargetFPS(config.target_fps)
	}

	time_init()

	g_running = true

	log_info("Engine ready")
}

start :: proc() {
	if g_hooks.on_init != nil {
		g_hooks.on_init()
	}
}

shutdown :: proc() {
	log_info("Engine shutting down")

	if g_hooks.on_shutdown != nil {
		g_hooks.on_shutdown()
	}

	rl.CloseWindow()
	memory_shutdown()
	log_info("Engine shutdown complete")
}

is_running :: proc() -> bool {
	return g_running && !rl.WindowShouldClose()
}

// frame executes one full engine tick
// 1. reset frame arena
// 2. poll os events
// 3. snapshot input once per frame
// 4. run N fixed updates (game simulation)
// 5. variable render pass
frame :: proc() {
	memory_frame_reset()
	rl.PollInputEvents()
	input.snapshot()

	steps := time_begin_frame()

	for i in 0 ..< steps {
		if g_hooks.on_fixed_update != nil {
			g_hooks.on_fixed_update(time_fixed_delta())
		}
	}

	// Variable render pass
	if g_hooks.on_render != nil {
		g_hooks.on_render(time_real_delta())
	}
}

request_quit :: proc() {
	g_running = false
}
