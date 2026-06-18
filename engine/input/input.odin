package input

import rl "vendor:raylib"

// Key and button enumerations

Key :: enum i32 {
	// Movement
	W      = 87,
	A      = 65,
	S      = 83,
	D      = 68,
	// Actions
	Space  = 32,
	Shift  = 340, // lshift
	Ctrl   = 341, // lctrl
	Escape = 256,
	// Arrow keys
	Up     = 265,
	Down   = 264,
	Left   = 263,
	Right  = 262,
}

Mouse_Button :: enum i32 {
	Left   = 0,
	Right  = 1,
	Middle = 2,
}

// Snapshot types

Key_Snapshot :: struct {
	w, a, s, d:                                            bool,
	space, shift, ctrl:                                    bool,
	escape:                                                bool,
	up, down, left, right:                                 bool,

	// "just pressed" variants
	w_pressed, a_pressed, s_pressed, d_pressed:            bool,
	space_pressed, shift_pressed, ctrl_pressed:            bool,
	escape_pressed:                                        bool,
	up_pressed, down_pressed, left_pressed, right_pressed: bool,
}

Mouse_Snapshot :: struct {
	x, y:                                        f32,
	dx, dy:                                      f32,
	scroll:                                      f32,
	left, right, middle:                         bool,
	left_pressed, right_pressed, middle_pressed: bool,

	// used to compute delta
	_prev_x:                                     f32,
	_prev_y:                                     f32,
}

Input_Snapshot :: struct {
	keys:  Key_Snapshot,
	mouse: Mouse_Snapshot,
}

// Module state

@(private)
g_snapshot: Input_Snapshot

snapshot :: proc() {
	_build_key_snapshot(&g_snapshot.keys)
	_build_mouse_snapshot(&g_snapshot.mouse)
}

get :: proc() -> ^Input_Snapshot {
	return &g_snapshot
}

// Internal builders

@(private)
_build_key_snapshot :: proc(k: ^Key_Snapshot) {
	k.w = rl.IsKeyDown(.W)
	k.a = rl.IsKeyDown(.A)
	k.s = rl.IsKeyDown(.S)
	k.d = rl.IsKeyDown(.D)
	k.space = rl.IsKeyDown(.SPACE)
	k.shift = rl.IsKeyDown(.LEFT_SHIFT)
	k.ctrl = rl.IsKeyDown(.LEFT_CONTROL)
	k.escape = rl.IsKeyDown(.ESCAPE)
	k.up = rl.IsKeyDown(.UP)
	k.down = rl.IsKeyDown(.DOWN)
	k.left = rl.IsKeyDown(.LEFT)
	k.right = rl.IsKeyDown(.RIGHT)

	k.w_pressed = rl.IsKeyPressed(.W)
	k.a_pressed = rl.IsKeyPressed(.A)
	k.s_pressed = rl.IsKeyPressed(.S)
	k.d_pressed = rl.IsKeyPressed(.D)
	k.space_pressed = rl.IsKeyPressed(.SPACE)
	k.shift_pressed = rl.IsKeyPressed(.LEFT_SHIFT)
	k.ctrl_pressed = rl.IsKeyPressed(.LEFT_CONTROL)
	k.escape_pressed = rl.IsKeyPressed(.ESCAPE)
	k.up_pressed = rl.IsKeyPressed(.UP)
	k.down_pressed = rl.IsKeyPressed(.DOWN)
	k.left_pressed = rl.IsKeyPressed(.LEFT)
	k.right_pressed = rl.IsKeyPressed(.RIGHT)
}

@(private)
_build_mouse_snapshot :: proc(m: ^Mouse_Snapshot) {
	pos := rl.GetMousePosition()
	m.dx = pos.x - m._prev_x
	m.dy = pos.y - m._prev_y
	m.x = pos.x
	m.y = pos.y
	m._prev_x = pos.x
	m._prev_y = pos.y

	delta := rl.GetMouseWheelMoveV()
	m.scroll = delta.y

	m.left = rl.IsMouseButtonDown(.LEFT)
	m.right = rl.IsMouseButtonDown(.RIGHT)
	m.middle = rl.IsMouseButtonDown(.MIDDLE)

	m.left_pressed = rl.IsMouseButtonPressed(.LEFT)
	m.right_pressed = rl.IsMouseButtonPressed(.RIGHT)
	m.middle_pressed = rl.IsMouseButtonPressed(.MIDDLE)
}
