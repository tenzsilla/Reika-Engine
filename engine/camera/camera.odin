package camera

import "../rmath"

// Reika camera
//
// Camera is a pure data object. Systems that need to derive matrices from
// it use the camera_*_matrix procs in this package; the renderer reads it
// with a borrowed pointer during submit()

// Types

Camera_Projection :: enum {
	Perspective,
	Orthographic,
}

// Camera uses Reika math only
Camera :: struct {
	position:   rmath.Vec3,
	target:     rmath.Vec3,
	up:         rmath.Vec3,
	fovy:       f32, // vertical fov in degrees (perspective only)
	projection: Camera_Projection,
}

DEFAULT_CAMERA :: Camera {
	position   = {5, 5, 5},
	target     = {0, 0, 0},
	up         = {0, 1, 0},
	fovy       = 60.0,
	projection = .Perspective,
}

// Matrix procs (pure functions of Camera state)
//
// Aspect ratio is not stored on the Camera because it depends on the window,
// which the camera shouldn't know about. Callers pass the current aspect
// (window width / window height) to camera_projection_matrix()
//
// For .Orthographic, fovy is ignored and the projection is a unit cube
// ortho; we'll eventually extend the Camera struct (or add an ortho_size
// field) when orthographic art direction needs an actual real size

camera_view_matrix :: proc(cam: Camera) -> rmath.Mat4 {
	return rmath.mat4_look_at(cam.position, cam.target, cam.up)
}

camera_projection_matrix :: proc(cam: Camera, aspect: f32, near_z: f32, far_z: f32) -> rmath.Mat4 {
	switch cam.projection {
	case .Perspective:
		return rmath.mat4_perspective(cam.fovy, aspect, near_z, far_z)
	case .Orthographic:
		// default ortho of [-1, 1] on all axes
		return rmath.mat4_orthographic(-1.0, 1.0, -1.0, 1.0, near_z, far_z)
	}
	return rmath.MAT4_IDENTITY
}

// projection * view for convenience
camera_view_projection_matrix :: proc(
	cam: Camera,
	aspect: f32,
	near_z: f32,
	far_z: f32,
) -> rmath.Mat4 {
	v := camera_view_matrix(cam)
	p := camera_projection_matrix(cam, aspect, near_z, far_z)
	return rmath.mat4_mul(p, v)
}
