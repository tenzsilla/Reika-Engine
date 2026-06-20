package profiler

// Reika profiler
//
// It records pre-frame timing and fixed-step count. The engine calls
// begin_frame()/end_frame() once per frame; the game reads get_snapshot()
// to compose an overlay string (drawn with render.draw_test)
//
// FPS smoothing uses an exponential moving average so the readout doesn't
// jitter every frame. The EMA weight is tuned for ~0.5s of an effective
// window which feels readable without lagging too far behind real changes

EMA_WEIGHT :: f32(0.1) // 0.0 = never update, 1.0 = no smoothing

Snapshot :: struct {
	fps:         f32,
	frame_ms:    f32,
	fixed_steps: f32,
}

@(private)
g_state: struct {
	ema_fps:      f32,
	ema_frame_ms: f32,
	ema_steps:    f32,
	frame_count:  u64,
} = {}

// Records the completion of a frame
end_frame :: proc(real_delta_s: f32, fixed_steps: int) {
	delta_s := real_delta_s
	if delta_s < 0 do delta_s = 0

	frame_ms := delta_s * 1000.0
	fps := f32(0)
	if delta_s > 1e-6 do fps = 1.0 / delta_s

	steps_f := f32(fixed_steps)

	if g_state.frame_count == 0 {
		g_state.ema_frame_ms = frame_ms
		g_state.ema_fps = fps
		g_state.ema_steps = steps_f
	} else {
		g_state.ema_frame_ms += EMA_WEIGHT * (frame_ms - g_state.ema_frame_ms)
		g_state.ema_fps += EMA_WEIGHT * (fps - g_state.ema_fps)
		g_state.ema_steps += EMA_WEIGHT * (steps_f - g_state.ema_steps)
	}

	g_state.frame_count += 1
}

// Returns a snapshot of the most recent profiler state
get_snapshot :: proc() -> Snapshot {
	return Snapshot {
		fps = g_state.ema_fps,
		frame_ms = g_state.ema_frame_ms,
		fixed_steps = g_state.ema_steps,
	}
}

// Reset all state
reset :: proc() {
	g_state = {}
}
