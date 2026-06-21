package ecs

import "../core"

// Entity ID
//
// Entity = u32 packed as:
// 		bits 0..21 -- index (22 bits = 4,194,304 max live entities)
// 		bits 22..32 -- generation (10 bits = 1,024 generations per slot)
//
// A handle whose generation doesn't match the pool's stored generation is stale and invalid
// ID 0 is reserved as ENTITY_INVALID

Entity :: distinct u32

ENTITY_INVALID :: Entity(0)

ENTITY_INDEX_BITS :: 22
ENTITY_GEN_BITS :: 10

ENTITY_INDEX_MASK :: Entity((1 << ENTITY_INDEX_BITS) - 1)
ENTITY_GEN_SHIFT :: ENTITY_INDEX_BITS
ENTITY_GEN_MASK :: Entity((1 << ENTITY_GEN_BITS) - 1)

entity_index :: #force_inline proc(e: Entity) -> u32 {
	return u32(e & ENTITY_INDEX_MASK)
}

entity_generation :: #force_inline proc(e: Entity) -> u32 {
	return u32((e >> ENTITY_GEN_SHIFT) & ENTITY_GEN_MASK)
}

entity_make :: #force_inline proc(index: u32, gen: u32) -> Entity {
	return Entity(index) | Entity(gen) << ENTITY_GEN_SHIFT
}

// Entity Pool
//
// Backed by the permanent arena and allocated once at init
// Free list is a LIFO stack of recycled indices

MAX_ENTITIES :: 65536

Entity_Pool :: struct {
	// Generation counter per slot
	generations:  []u16,
	// lifo free list of recycled indices
	free_list:    []u32,
	free_head:    int, // Stack top
	// Grows until MAX_ENTITIES
	next_index:   u32,
	// Current entity count
	count:        int,
	live_indices: []u32,
}

@(private)
g_pool: Entity_Pool

entity_pool_init :: proc() -> bool {
	arena := core.mem_permanent()

	g_pool.generations = core.arena_push_slice(arena, u16, MAX_ENTITIES, "entity_generations")
	g_pool.free_list = core.arena_push_slice(arena, u32, MAX_ENTITIES, "entity_free_list")
	g_pool.live_indices = core.arena_push_slice(arena, u32, MAX_ENTITIES, "entity_live_indices")

	if g_pool.generations == nil || g_pool.free_list == nil || g_pool.live_indices == nil {
		core.log_error("ECS: entity pool allocation failed")
		return false
	}

	g_pool.free_head = -1
	g_pool.next_index = 1 // since 0 is reserved for ENTITY_INVALID
	g_pool.count = 0

	core.log_info("ECS: entity pool ready (max %d entities)", MAX_ENTITIES)
	return true
}

// entity_create issues a new entity ID
entity_create :: proc() -> Entity {
	idx: u32

	if g_pool.free_head >= 0 {
		// recycle a freed slot
		idx = g_pool.free_list[g_pool.free_head]
		g_pool.free_head -= 1
	} else if g_pool.next_index < MAX_ENTITIES {
		idx = g_pool.next_index
		g_pool.next_index += 1
	} else {
		core.log_error("ECS: entity pool exhausted (max %d)", MAX_ENTITIES)
		return ENTITY_INVALID
	}

	gen := u32(g_pool.generations[idx])
	g_pool.live_indices[g_pool.count] = idx
	g_pool.count += 1
	return entity_make(idx, gen)
}

// entity_destroy invalidates the entity and returns its slot to the free list
entity_destroy :: proc(e: Entity) {
	if e == ENTITY_INVALID do return

	idx := entity_index(e)
	if !entity_alive(e) {
		core.log_warn("ECS: entity_destroy called on stale entity %d", u32(e))
		return
	}

	// Bump generation to invalidate all existing handles to this slot
	g_pool.generations[idx] = (g_pool.generations[idx] + 1) % (1 << ENTITY_GEN_BITS)

	// swap remove from live_indices (O(count) per destroy)
	for i in 0 ..< g_pool.count {
		if g_pool.live_indices[i] == idx {
			g_pool.live_indices[i] = g_pool.live_indices[g_pool.count - 1]
			break
		}
	}

	g_pool.free_head += 1
	g_pool.free_list[g_pool.free_head] = idx
	g_pool.count -= 1
}

entity_alive :: proc(e: Entity) -> bool {
	if e == ENTITY_INVALID do return false
	idx := entity_index(e)
	if idx == 0 || idx >= g_pool.next_index do return false
	return u32(g_pool.generations[idx]) == entity_generation(e)
}

entity_count :: proc() -> int {return g_pool.count}

// returns the compact slice of live entity slot indices
live_indices :: proc() -> []u32 {
	return g_pool.live_indices[:g_pool.count]
}
