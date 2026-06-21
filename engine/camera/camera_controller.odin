package camera

import "../input"
import "../rmath"
import "core:math"

// Camera controller
//
// Owns the camera behavior (movement, look input, mode)
// The Camera struct remains the authoritative source of position/target/up/
// projection. The controller writes camera.position directly during movement
// and derives camera.target from (yaw, pitch) at the end of each update
//
// Future cameras (FPS, third person, cinematic, editor) implement the same
// pattern: a controller struct with its own update proc that writes to a
// Camera

// Controller

Camera_Controller :: struct {
	// Camera being driven
	camera:            ^Camera,

	// Translation speed in world units per second
	movement_speed:    f32,

	// Look sensitivity in degrees per pixel of mouse delta
	mouse_sensitivity: f32,

	// Yaw/pitch in degrees
	yaw:               f32,
	pitch:             f32,
}

// Default tunables for the free fly debug camera
DEFAULT_CONTROLLER_MOVEMENT_SPEED :: f32(8.0) // 8 units/s
DEFAULT_CONTROLLER_MOUSE_SENSITIVITY :: f32(0.25) // 0.25 deg/pixel

PITCH_CLAMP_DEG :: f32(89.0)

// Init
//
// Caller owns the Camera_Controller storage

camera_controller_init :: proc(camera: ^Camera) -> Camera_Controller {
	return Camera_Controller {
		camera = camera,
		movement_speed = DEFAULT_CONTROLLER_MOVEMENT_SPEED,
		mouse_sensitivity = DEFAULT_CONTROLLER_MOUSE_SENSITIVITY,
		yaw = 0.0,
		pitch = 0.0,
	}
}

// Update
//
// Movement (read from the current input snapshot):
//      W/S: forward/backward (along look direction, XZ projected)
//      A/D: strafe left/right
//      Q/E: descend/ascend (world Y)
//
// Look (only while rmb is held)

camera_controller_update :: proc(ctrl: ^Camera_Controller, dt: f32) {
	cam := ctrl.camera
	snap := input.get()

	// Look
	if snap.mouse.right {
		yaw_delta := snap.mouse.dx * ctrl.mouse_sensitivity
		pitch_delta := snap.mouse.dy * ctrl.mouse_sensitivity

		// Flight sim
		ctrl.yaw -= yaw_delta
		ctrl.pitch -= pitch_delta

		// Clamp pitch to avoid gimbal flip at the poles
		if ctrl.pitch > PITCH_CLAMP_DEG do ctrl.pitch = PITCH_CLAMP_DEG
		if ctrl.pitch < -PITCH_CLAMP_DEG do ctrl.pitch = -PITCH_CLAMP_DEG
	}

	// Forward/right basis derived from yaw/pitch
	// Right-handed, Y up, -Z forward
	yaw_rad := rmath.deg_to_rad(ctrl.yaw)
	pitch_rad := rmath.deg_to_rad(ctrl.pitch)

	cy := f32(math.cos(f64(yaw_rad)))
	sy := f32(math.sin(f64(yaw_rad)))
	cp := f32(math.cos(f64(pitch_rad)))
	sp := f32(math.sin(f64(pitch_rad)))

	// Full look direction (used for target)
	forward := rmath.Vec3 {
		x = -cp * sy,
		y = sp,
		z = -cp * cy,
	}

	// XZ projected forward for WASD movement
	forward_xz := rmath.vec3_normalize(rmath.Vec3{x = forward.x, y = 0, z = forward.z})

	right := rmath.vec3_normalize(rmath.vec3_cross(forward_xz, rmath.VEC3_UP))

	// Translation
	speed := ctrl.movement_speed * dt

	move := rmath.VEC3_ZERO
	if snap.keys.w do move = rmath.vec3_add(move, forward_xz)
	if snap.keys.s do move = rmath.vec3_sub(move, forward_xz)
	if snap.keys.d do move = rmath.vec3_add(move, right)
	if snap.keys.a do move = rmath.vec3_sub(move, right)
	if snap.keys.e do move.y += 1.0
	if snap.keys.q do move.y -= 1.0

	if rmath.vec3_length_sq(move) > rmath.EPSILON {
		move = rmath.vec3_normalize(move)
		cam.position = rmath.vec3_add(cam.position, rmath.vec3_scale(move, speed))
	}

	// Commit target
	cam.target = rmath.vec3_add(cam.position, forward)
	cam.up = rmath.VEC3_UP
}
