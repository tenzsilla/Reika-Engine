package render

import "../core"
import "../rmath"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Reika renderer
// 
// Modern raylib/OpenGL backend intentionally reproducing the PS2-era 
// visual language with: vertex dominant CPU lighting, single directional
// light, flat render command pipeline. The renderer consumes pre-built
// render commands and never queries ECS or any gameplay state directly
// 
// The renderer owns the camera state, directional light state, built-in
// unit cube geometry. Though the renderer does NOT own the command slice
// (the caller owns it, while the renderer reads only), ECS state, and
// gameplay state.
// 
// Raylib types never leave this package. Reika math types are the public
// API; conversion to rl.* happens internally with transmuting (layout
// compatible by design, see rmath/math.odin)