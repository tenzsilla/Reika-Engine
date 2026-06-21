package material

import "../core"
import "../render"
import "../rmath"

// Reika material service
//
// Materials are static data-only assets created during game launch which
// define the looks of meshes. Texture handles, filter modes, tint colors,
// lighting models, fog responses, and PS1 retro effect flags are all
// components of a material. Materials are kept in a limited-capacity
// array with references through 1-based Material Handles (u32), thereby
// allowing the ECS to be independent of the material system. The core
// enums from the rendering system are imported by the material package,
// but the rendering system has no knowledge of materials stored in memory;
// this is done by folding material fields into the Render Command at
// build time, creating a strict one direction flow for dependencies
// (rmath <- render <- material <- game)

// Public types

Material_Handle :: distinct u32
MATERIAL_INVALID :: Material_Handle(0xFFFFFFFF)
MATERIAL_DEFAULT :: Material_Handle(0)

// Material describes how a mesh should be drawn
Material :: struct {
	texture:      render.Texture_Handle,
	filter:       render.Filter_Mode,
	tint:         rmath.Vec3,
	lighting:     render.Lighting_Model,
	fog_response: render.Fog_Response,
	vertex_snap:  bool,
	affine_uv:    bool,
	dither:       bool,
}

Material_Props :: struct {
	texture:      render.Texture_Handle,
	filter:       render.Filter_Mode,
	tint:         rmath.Vec3,
	lighting:     render.Lighting_Model,
	fog_response: render.Fog_Response,
	vertex_snap:  bool,
	affine_uv:    bool,
	dither:       bool,
}

MATERIAL_DEFAULT_PROPS :: Material_Props {
	texture      = render.TEXTURE_INVALID,
	filter       = .Nearest,
	tint         = {1, 1, 1},
	lighting     = .Lambert,
	fog_response = .Affected,
	vertex_snap  = false,
	affine_uv    = false,
	dither       = false,
}

// Storage

MAX_MATERIALS :: 512

@(private)
g_materials: [MAX_MATERIALS]Material

@(private)
g_material_count: int = 0

// Lifecycle

init :: proc() {
	g_material_count = 0

	// Reserve slot 0 for the default material
	default := Material {
		texture      = render.TEXTURE_INVALID,
		filter       = .Nearest,
		tint         = {1, 1, 1},
		lighting     = .Lambert,
		fog_response = .Affected,
		vertex_snap  = false,
		affine_uv    = false,
		dither       = false,
	}
	g_materials[0] = default
	g_material_count = 1

	core.log_info("Material service ready")
}

// Accessors

material_create :: proc(props: Material_Props) -> Material_Handle {
	if g_material_count >= MAX_MATERIALS {
		return MATERIAL_INVALID
	}
	idx := g_material_count
	g_materials[idx] = Material {
		texture      = props.texture,
		filter       = props.filter,
		tint         = props.tint,
		lighting     = props.lighting,
		fog_response = props.fog_response,
		vertex_snap  = props.vertex_snap,
		affine_uv    = props.affine_uv,
		dither       = props.dither,
	}
	g_material_count += 1
	return Material_Handle(idx)
}

material_get :: proc(handle: Material_Handle) -> ^Material {
	if handle == MATERIAL_INVALID do return nil
	idx := int(handle)
	if idx < 0 || idx >= g_material_count do return nil
	return &g_materials[idx]
}

material_count :: proc() -> int {
	return g_material_count
}
