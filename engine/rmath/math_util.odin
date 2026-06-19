package rmath

import "core:math"

// Reika math utilities
//
// Angle conversion, Euler<->Quat helpers (XYZ Tait-bryan, degrees, [-180,180]),
// transform composition helpers, and a small set of interpolation utilities.
//
// Euler convention (locked):
// 		Order: XYZ Tait-Bryan. Applied X (pitch) then Y (yaw) then Z (roll)
// 		Equivalently: q = qz * qy * qx (intrinsic XYZ == extrinsic ZYX)
// 		Range: each axis in [-180, 180] degrees
// 		Public API always uses degrees; internal trig uses radians
//
// Euler exists ONLY for Lua/editor/debug use. Engine systems must operate
// directly on quaternions

// Angle conversion

deg_to_rad :: proc(deg: f32) -> f32 {
	return deg * DEG_TO_RAD
}

rad_to_deg :: proc(rad: f32) -> f32 {
	return rad * RAD_TO_DEG
}

// Wraps an angle in degrees to [-180, 180]
wrap_degrees :: proc(deg: f32) -> f32 {
	r := f32(math.mod(f64(deg) + 180.0, 360.0))
	if r < 0 do r += 360.0
	return r - 180.0
}

// Quat <-> Euler (XYZ Tait-bryan, degrees)
//
// Reference: standard quaternion-to-Euler derivation adapted to the
// XYZ Tait-Bryan case. The forward (set) path multiplies qx*qy*qz
// The inverse (get) path derives pitch/yaw/roll from the resulting matrix

// Builds a quaternion from Euler angles in degrees, XYZ tait-bryan order
// pitch (x), yaw (y), roll (z) all in [-180, 180]
quat_from_euler_deg :: proc(pitch_deg, yaw_deg, roll_deg: f32) -> Quat {
	hx := deg_to_rad(pitch_deg) * 0.5
	hy := deg_to_rad(yaw_deg) * 0.5
	hz := deg_to_rad(roll_deg) * 0.5

	cx := f32(math.cos(f64(hx)))
	sx := f32(math.sin(f64(hx)))
	cy := f32(math.cos(f64(hy)))
	sy := f32(math.sin(f64(hy)))
	cz := f32(math.cos(f64(hz)))
	sz := f32(math.sin(f64(hz)))

	// q = qz * qy * qx  (intrinsic XYZ order)
	// cx/cy/cz are cos(half-angles), sx/sy/sz are sin(half-angles)
	return Quat {
		x = sx * cy * cz - cx * sy * sz,
		y = cx * sy * cz + sx * cy * sz,
		z = cx * cy * sz - sx * sy * cz,
		w = cx * cy * cz + sx * sy * sz,
	}
}

// Returns Euler angles in degrees, XYZ Tait-Bryan order, each in [-180, 180]
// pitch (x), yaw (y), roll (z)
//
// Derivation: extract the rotation matrix entries from the quaternion and
// solve for the Tait-Bryan angles. Singularity at pitch = +/-90deg is
// handled by collapsing yaw/roll into a single rotation about Y
quat_to_euler_deg :: proc(q: Quat) -> (pitch_deg, yaw_deg, roll_deg: f32) {
	// Normalize input to keep the conversion stable on a dirty input
	nq := quat_normalize(q)

	// For XYZ Tait-bryan (q = qz*qy*qx), the rotation matrix entry
	// R[1][0] (row 1, col 0) is 2*(xy + wz), and ranges over [-1, 1]
	// representing sin(pitch). When |2*(xy+wz)| ~ 1, gimbal lock
	sinp := 2.0 * (nq.x * nq.y + nq.w * nq.z)
	sinp = clamp(sinp, -1.0, 1.0)

	pitch_rad: f64
	yaw_rad: f64
	roll_rad: f64

	if math.abs(f64(sinp)) > 1.0 - f64(EPSILON) {
		// Gimbal lock: pitch is +/-90deg. Set roll = 0 and solve yaw
		pitch_rad = f64(math.copy_sign(f32(math.PI / 2.0), sinp))
		yaw_rad = f64(
			math.atan2(
				f64(-2.0 * (nq.y * nq.z - nq.w * nq.x)),
				f64(2.0 * (nq.w * nq.w + nq.y * nq.y) - 1.0),
			),
		)
		roll_rad = 0.0
	} else {
		pitch_rad = f64(math.asin(f32(sinp)))
		yaw_rad = f64(
			math.atan2(
				f64(2.0 * (nq.x * nq.z - nq.w * nq.y)),
				f64(2.0 * (nq.w * nq.w + nq.x * nq.x) - 1.0),
			),
		)
		roll_rad = f64(
			math.atan2(
				f64(2.0 * (nq.y * nq.z - nq.w * nq.x)),
				f64(2.0 * (nq.w * nq.w + nq.z * nq.z) - 1.0),
			),
		)
	}

	return rad_to_deg(f32(pitch_rad)), rad_to_deg(f32(yaw_rad)), rad_to_deg(f32(roll_rad))
}

// Transform
//
// Position/translation in world or parent space, rotation as a unit
// quaternion, scale as a Vec3. Engine systems read these fields directly
// and never touch Euler. Euler helpers below are for tooling/Lua only

Transform :: struct {
	position: Vec3,
	rotation: Quat,
	scale:    Vec3,
}

TRANSFORM_IDENTITY :: Transform {
	position = {0, 0, 0},
	rotation = QUAT_IDENTITY,
	scale    = {1, 1, 1},
}

// Sets a transform's rotation from Euler angles in degrees (XYZ Tait-Bryan)
// Convenience for Lua/editor/debug. Engine systems should compose quaternions
// directly
transform_set_euler :: proc(t: ^Transform, pitch_deg, yaw_deg, roll_deg: f32) {
	t.rotation = quat_from_euler_deg(pitch_deg, yaw_deg, roll_deg)
}

// Reads a transform's rotation as Euler angles in degrees (XYZ Tait-Bryan,
// each in [-180, 180]). Lossy by nature so we do not use it for engine logic
transform_get_euler :: proc(t: Transform) -> (pitch_deg, yaw_deg, roll_deg: f32) {
	return quat_to_euler_deg(t.rotation)
}

// Composes a TRS world matrix from a Transform
transform_to_mat4 :: proc(t: Transform) -> Mat4 {
	return mat4_trs(t.position, t.rotation, t.scale)
}

// Linearly interpolates two Transforms: position and scale use lerp,
// rotation uses slerp. t in [0,1]
transform_lerp :: proc(a, b: Transform, t: f32) -> Transform {
	return Transform {
		position = vec3_lerp(a.position, b.position, t),
		rotation = quat_slerp(a.rotation, b.rotation, t),
		scale = vec3_lerp(a.scale, b.scale, t),
	}
}

// Scalar interpolation/utilities

lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

// Smoothstep (Hermite). t clamped to [0,1]
smoothstep :: proc(t: f32) -> f32 {
	c := clamp(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
}

clamp :: proc(v, lo, hi: f32) -> f32 {
	if v < lo do return lo
	if v > hi do return hi
	return v
}

clamp01 :: proc(v: f32) -> f32 {
	return clamp(v, 0.0, 1.0)
}

// View matrices
//
// Right-handed, Y-up. -Z is forward (matching VEC3_FORWARD)

// Builds a right-handed look-from view matrix
// eye : camera position
// target : point the camera looks at
// up : up vector (typically VEC3_UP)
mat4_look_at :: proc(eye, target, up: Vec3) -> Mat4 {
	f := vec3_normalize(vec3_sub(target, eye)) // forward
	s := vec3_normalize(vec3_cross(f, up)) // right
	u := vec3_cross(s, f) // true up

	// View matrix translates world by -eye, then rotates so camera looks
	// down -Z. Standard RH formulation:
	//   [ s.x  s.y  s.z  -dot(s,eye) ]
	//   [ u.x  u.y  u.z  -dot(u,eye) ]
	//   [-f.x -f.y -f.z   dot(f,eye) ]
	//   [  0    0    0          1    ]
	return Mat4 {
		m = {
			s.x,
			u.x,
			-f.x,
			0,
			s.y,
			u.y,
			-f.y,
			0,
			s.z,
			u.z,
			-f.z,
			0,
			-vec3_dot(s, eye),
			-vec3_dot(u, eye),
			vec3_dot(f, eye),
			1,
		},
	}
}

// Right-handed perspective projection. fovy in degrees, aspect = w/h
mat4_perspective :: proc(fovy_deg: f32, aspect: f32, near_z: f32, far_z: f32) -> Mat4 {
	f := 1.0 / f32(math.tan(f64(deg_to_rad(fovy_deg)) * 0.5))
	// Avoid degenerate aspect producing inf
	if math.abs(aspect) < EPSILON {
		return MAT4_IDENTITY
	}
	inv_aspect := 1.0 / aspect
	range := far_z - near_z
	if math.abs(range) < EPSILON {
		return MAT4_IDENTITY
	}
	// Standard OpenGL/Raylib style column major perspective
	// Negates Z so that the camera looks down -Z and depth is non positive
	return Mat4 {
		m = {
			f * inv_aspect,
			0,
			0,
			0,
			0,
			f,
			0,
			0,
			0,
			0,
			-(far_z + near_z) / range,
			-1,
			0,
			0,
			-(2.0 * far_z * near_z) / range,
			0,
		},
	}
}

// Right-handed orthographic projection
mat4_orthographic :: proc(left, right, bottom, top, near_z, far_z: f32) -> Mat4 {
	rl := right - left
	tb := top - bottom
	fn := far_z - near_z
	if math.abs(rl) < EPSILON || math.abs(tb) < EPSILON || math.abs(fn) < EPSILON {
		return MAT4_IDENTITY
	}
	return Mat4 {
		m = {
			2.0 / rl,
			0,
			0,
			0,
			0,
			2.0 / tb,
			0,
			0,
			0,
			0,
			-2.0 / fn,
			0,
			-(right + left) / rl,
			-(top + bottom) / tb,
			-(far_z + near_z) / fn,
			1,
		},
	}
}
