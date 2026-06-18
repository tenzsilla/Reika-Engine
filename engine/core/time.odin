package core

import rl "vendor:raylib"

// All durations are in seconds (f64 for accumulator precision, f32 for per-frame use)

FIXED_UPDATE_HZ :: 60
FIXED_DELTA_TIME :: f64(1.0 / FIXED_UPDATE_HZ)

// Max number of fixed steps per frame before we drop time
MAX_FIXED_STEPS :: 5

Time_State :: struct {
	// Wall clock time at the start of the current frame
	now:                    f64,
	// Wall clock time at the start of the previous frame
	prev:                   f64,
	// Real elapsed time this frame (variable)
	real_delta:             f32,
	// Fixed simulation delta
	fixed_delta:            f32,
	// Leftover time not yet consumed by fixed steps
	// When interpolation is added, we'll pass (accumulator / FIXED_DELTA_TIME)
	// as the alpha to the render system here
	accumulator:            f64,
	// Total simulated time since engine start
	sim_time:               f64,
	// Total real time since engine start
	real_time:              f64,
	// Number of fixed steps executed this frame
	fixed_steps_this_frame: int,
}

@(private)
g_time: Time_State

time_init :: proc() {
	g_time = {}
	g_time.fixed_delta = f32(FIXED_DELTA_TIME)
	g_time.now = f64(rl.GetTime())
	g_time.prev = g_time.now
}

// Called once at the top of each frame before any system update
time_begin_frame :: proc() -> int {
	g_time.prev = g_time.now
	g_time.now = f64(rl.GetTime())
	frame_time := g_time.now - g_time.prev
	g_time.real_delta = f32(frame_time)
	g_time.real_time += frame_time

	// Clamp to prevent spiral of death
	clamped := min(frame_time, f64(MAX_FIXED_STEPS) * FIXED_DELTA_TIME)
	g_time.accumulator += clamped

	steps := 0
	for g_time.accumulator >= FIXED_DELTA_TIME && steps < MAX_FIXED_STEPS {
		g_time.accumulator -= FIXED_DELTA_TIME
		g_time.sim_time += FIXED_DELTA_TIME
		steps += 1
	}

	g_time.fixed_steps_this_frame = steps
	return steps
}

time_get :: proc() -> ^Time_State {
	return &g_time
}

// Convenience accessors
time_real_delta :: proc() -> f32 {return g_time.real_delta}
time_fixed_delta :: proc() -> f32 {return g_time.fixed_delta}
time_sim_time :: proc() -> f64 {return g_time.sim_time}
time_real_time :: proc() -> f64 {return g_time.real_time}
