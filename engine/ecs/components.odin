package ecs

import "../core"
import "../rmath"

// Component Arrays
//
// Each component type is a flat array indexed by entity index
// Valid/invalid is tracked per component with a presence array
// and not by nulling out data, which keeps component arrays dense
// for iteration and avoids branch heavy null checks in systems
//
// Layout: Structure of Arrays (SoA) per component type
// This keeps each field contiguous in memory for cache friendly
// iteration when systems only need a subset of fields

// Mesh_Renderer
//
// References a mesh and material by asset handle (u32 IDs)

Mesh_Renderer :: struct {
	mesh_id:     u32,
	material_id: u32,
	visible:     bool,
}

// Component Arrays
//
// One flat array per component type, sized to MAX_ENTITIES
// `has` arrays track which entities own each component
// All memory is from the permanent arena

Component_Arrays :: struct {
	// Transform
	transform:         []rmath.Transform,
	has_transform:     []bool,

	// Mesh_Renderer
	mesh_renderer:     []Mesh_Renderer,
	has_mesh_renderer: []bool,
}

@(private)
g_components: Component_Arrays

component_arrays_init :: proc() -> bool {
	arena := core.mem_permanent()

	g_components.transform = core.arena_push_slice(
		arena,
		rmath.Transform,
		MAX_ENTITIES,
		"transform",
	)
	g_components.has_transform = core.arena_push_slice(arena, bool, MAX_ENTITIES, "has_transform")
	g_components.mesh_renderer = core.arena_push_slice(
		arena,
		Mesh_Renderer,
		MAX_ENTITIES,
		"mesh_renderer",
	)
	g_components.has_mesh_renderer = core.arena_push_slice(
		arena,
		bool,
		MAX_ENTITIES,
		"has_mesh_renderer",
	)

	if g_components.transform == nil ||
	   g_components.has_transform == nil ||
	   g_components.mesh_renderer == nil ||
	   g_components.has_mesh_renderer == nil {
		core.log_error("ECS: component array allocation failed")
		return false
	}

	core.log_info("ECS: component arrays ready")
	return true
}

// Transform accessors

transform_add :: proc(e: Entity, t: rmath.Transform = rmath.TRANSFORM_IDENTITY) -> bool {
	if !entity_alive(e) do return false
	idx := entity_index(e)
	g_components.transform[idx] = t
	g_components.has_transform[idx] = true
	return true
}

transform_remove :: proc(e: Entity) {
	if !entity_alive(e) do return
	idx := entity_index(e)
	g_components.has_transform[idx] = false
}

transform_has :: proc(e: Entity) -> bool {
	if !entity_alive(e) do return false
	return g_components.has_transform[entity_index(e)]
}

// Returns nil if the entity isn't alive or has no transform
transform_get :: proc(e: Entity) -> ^rmath.Transform {
	if !entity_alive(e) do return nil
	idx := entity_index(e)
	if !g_components.has_transform[idx] do return nil
	return &g_components.transform[idx]
}

// Mesh_Renderer accessors

mesh_renderer_add :: proc(e: Entity, mesh_id: u32, material_id: u32) -> bool {
	if !entity_alive(e) do return false
	idx := entity_index(e)
	g_components.mesh_renderer[idx] = Mesh_Renderer {
		mesh_id     = mesh_id,
		material_id = material_id,
		visible     = true,
	}
	g_components.has_mesh_renderer[idx] = true
	return true
}

mesh_renderer_remove :: proc(e: Entity) {
	if !entity_alive(e) do return
	g_components.has_mesh_renderer[entity_index(e)] = false
}

mesh_renderer_has :: proc(e: Entity) -> bool {
	if !entity_alive(e) do return false
	return g_components.has_mesh_renderer[entity_index(e)]
}

mesh_renderer_get :: proc(e: Entity) -> ^Mesh_Renderer {
	if !entity_alive(e) do return nil
	idx := entity_index(e)
	if !g_components.has_mesh_renderer[idx] do return nil
	return &g_components.mesh_renderer[idx]
}

// Iteration helpers
//
// Systems call these to get raw slices for cache friendly batch processing

transforms_raw :: proc() -> (data: []rmath.Transform, has: []bool) {
	return g_components.transform, g_components.has_transform
}

mesh_renderers_raw :: proc() -> (data: []Mesh_Renderer, has: []bool) {
	return g_components.mesh_renderer, g_components.has_mesh_renderer
}

// ECS init

ecs_init :: proc() -> bool {
	if !entity_pool_init() do return false
	if !component_arrays_init() do return false
	return true
}
