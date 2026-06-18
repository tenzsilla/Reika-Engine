package main

import "engine/core"
import "game"

main :: proc() {
	game.register()

	core.init()
	defer core.shutdown()

	for core.is_running() {
		core.frame()
	}
}
