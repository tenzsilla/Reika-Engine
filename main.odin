package main

import "engine/core"
import "engine/ecs"
import "game"

main :: proc() {
	game.register()

	core.init()
	defer core.shutdown()

	if !ecs.ecs_init() {
		core.log_error("main: ECS init failed")
		return
	}

	core.start()

	for core.is_running() {
		core.frame()
	}
}
