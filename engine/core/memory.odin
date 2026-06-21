package core

// Memory
//
// It has three subsystem-owned arenas with explicit lifetimes
//
// 		permanent -- entities, components, long-lived world state
// 					 Never reset during gameplay and destroyed at shutdown
//
// 		asset     -- meshes, textures, loaded resources
// 					 Reset only on full asset reload or scene transition
// 					 Destroyed at shutdown
//
// 		frame	  -- temporary allocations: render commands, scratch
// 					 query results, debug strings
// 					 Reset at the start of each frame by core.frame()
// 					 Never hold pointers into this across frames
//
// Sizes are set at init. Adjust per project in Memory_Config
// No single global allocator; each subsystem calls mem_permanent(),
// mem_asset(), or mem_frame() and allocates from the right arena

Memory_Config :: struct {
	permanent_bytes: int,
	asset_bytes:     int,
	frame_bytes:     int,
}

DEFAULT_MEMORY_CONFIG :: Memory_Config {
	permanent_bytes = 64 * 1024 * 1024, // 64 MB
	asset_bytes     = 256 * 1024 * 1024, // 256 MB
	frame_bytes     = 4 * 1024 * 1024, // 4 MB
}

@(private)
g_mem: struct {
	permanent: Arena,
	asset:     Arena,
	frame:     Arena,
	ready:     bool,
}

memory_init :: proc(config: Memory_Config = DEFAULT_MEMORY_CONFIG) -> bool {
	if !arena_init(&g_mem.permanent, config.permanent_bytes, "permanent") do return false
	if !arena_init(&g_mem.asset, config.asset_bytes, "asset") do return false
	if !arena_init(&g_mem.frame, config.frame_bytes, "frame") do return false

	g_mem.ready = true

	log_info(
		"Memory ready - permanent: %d MB, asset: %d MB, frame: %d MB",
		config.permanent_bytes / (1024 * 1024),
		config.asset_bytes / (1024 * 1024),
		config.frame_bytes / (1024 * 1024),
	)

	return true
}

memory_shutdown :: proc() {
	arena_destroy(&g_mem.frame)
	arena_destroy(&g_mem.asset)
	arena_destroy(&g_mem.permanent)
	g_mem.ready = false
	log_info("Memory released")
}

// Called by core.frame() at the start of each frame
// All frame arena pointers from the previous frame are invalid after this
memory_frame_reset :: proc() {
	arena_reset(&g_mem.frame)
}

// Accessors
// Callers receive a pointer to the arena and allocate directly

mem_permanent :: proc() -> ^Arena {return &g_mem.permanent}
mem_asset :: proc() -> ^Arena {return &g_mem.asset}
mem_frame :: proc() -> ^Arena {return &g_mem.frame}

// Debug

memory_debug_print_all :: proc() {
	when ODIN_DEBUG {
		arena_debug_print(&g_mem.permanent)
		arena_debug_print(&g_mem.asset)
		arena_debug_print(&g_mem.frame)
	}
}
