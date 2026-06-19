package rmath

import "core:math"

// Reika math layer
//
// f32 throughout. Right-handed, Y-up, degrees in the public API, radians
// internally. Column-major Mat4. Types are layout-compatible with Raylib's
// rl.Vector2/3/4, rl.Matrix, rl.Quaternion so the renderer can transmute
// (with zero cost) rather than copy field by field
//
// This module imports nothing from Raylib and nothing from engine packages.
// Conversion to Raylib types is the renderer's responsibility.

// Constants

PI :: f32(math.PI)
TAU :: f32(2.0 * math.PI)
DEG_TO_RAD :: f32(math.PI / 180.0)
RAD_TO_DEG :: f32(180.0 / math.PI)

EPSILON :: f32(1e-6)

// Vec2

Vec2 :: struct {
	x, y: f32,
}

VEC2_ZERO :: Vec2{0, 0}
VEC2_ONE :: Vec2{1, 1}

vec2 :: proc(x, y: f32) -> Vec2 {
	return Vec2{x, y}
}

vec2_add :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{a.x + b.x, a.y + b.y}
}

vec2_sub :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{a.x - b.x, a.y - b.y}
}

vec2_scale :: proc(v: Vec2, s: f32) -> Vec2 {
	return Vec2{v.x * s, v.y * s}
}

vec2_dot :: proc(a, b: Vec2) -> f32 {
	return a.x * b.x + a.y * b.y
}

vec2_length_sq :: proc(v: Vec2) -> f32 {
	return v.x * v.x + v.y * v.y
}

vec2_length :: proc(v: Vec2) -> f32 {
	return f32(math.sqrt(f64(vec2_length_sq(v))))
}

vec2_normalize :: proc(v: Vec2) -> Vec2 {
	l := vec2_length(v)
	if l < EPSILON do return VEC2_ZERO
	inv := 1.0 / l
	return Vec2{v.x * inv, v.y * inv}
}

vec2_lerp :: proc(a, b: Vec2, t: f32) -> Vec2 {
	return Vec2{a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t}
}

// Vec3

Vec3 :: struct {
	x, y, z: f32,
}

VEC3_ZERO :: Vec3{0, 0, 0}
VEC3_ONE :: Vec3{1, 1, 1}
VEC3_UP :: Vec3{0, 1, 0}
VEC3_DOWN :: Vec3{0, -1, 0}
VEC3_RIGHT :: Vec3{1, 0, 0}
VEC3_FORWARD :: Vec3{0, 0, -1} // Right-handed Y-up with -Z being forward
VEC3_BACK :: Vec3{0, 0, 1}

vec3 :: proc(x, y, z: f32) -> Vec3 {
	return Vec3{x, y, z}
}

vec3_add :: proc(a, b: Vec3) -> Vec3 {
	return Vec3{a.x + b.x, a.y + b.y, a.z + b.z}
}

vec3_sub :: proc(a, b: Vec3) -> Vec3 {
	return Vec3{a.x - b.x, a.y - b.y, a.z - b.z}
}

vec3_scale :: proc(v: Vec3, s: f32) -> Vec3 {
	return Vec3{v.x * s, v.y * s, v.z * s}
}

// Hadamard product, which is useful for scaling color/component-wise
vec3_mul :: proc(a, b: Vec3) -> Vec3 {
	return Vec3{a.x * b.x, a.y * b.y, a.z * b.z}
}

vec3_dot :: proc(a, b: Vec3) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3_cross :: proc(a, b: Vec3) -> Vec3 {
	return Vec3{a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}
}

vec3_length_sq :: proc(v: Vec3) -> f32 {
	return v.x * v.x + v.y * v.y + v.z * v.z
}

vec3_length :: proc(v: Vec3) -> f32 {
	return f32(math.sqrt(f64(vec3_length_sq(v))))
}

vec3_normalize :: proc(v: Vec3) -> Vec3 {
	l := vec3_length(v)
	if l < EPSILON do return VEC3_ZERO
	inv := 1.0 / l
	return Vec3{v.x * inv, v.y * inv, v.z * inv}
}

vec3_lerp :: proc(a, b: Vec3, t: f32) -> Vec3 {
	return Vec3{a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t}
}

// Reflects v about the normal n (assumed unit length)
vec3_reflect :: proc(v, n: Vec3) -> Vec3 {
	d := 2.0 * vec3_dot(v, n)
	return Vec3{v.x - n.x * d, v.y - n.y * d, v.z - n.z * d}
}

// Vec4

Vec4 :: struct {
	x, y, z, w: f32,
}

VEC4_ZERO :: Vec4{0, 0, 0, 0}
VEC4_ONE :: Vec4{1, 1, 1, 1}

vec4 :: proc(x, y, z, w: f32) -> Vec4 {
	return Vec4{x, y, z, w}
}

vec4_add :: proc(a, b: Vec4) -> Vec4 {
	return Vec4{a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w}
}

vec4_sub :: proc(a, b: Vec4) -> Vec4 {
	return Vec4{a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w}
}

vec4_scale :: proc(v: Vec4, s: f32) -> Vec4 {
	return Vec4{v.x * s, v.y * s, v.z * s, v.w * s}
}

vec4_dot :: proc(a, b: Vec4) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
}

vec4_lerp :: proc(a, b: Vec4, t: f32) -> Vec4 {
	return Vec4 {
		a.x + (b.x - a.x) * t,
		a.y + (b.y - a.y) * t,
		a.z + (b.z - a.z) * t,
		a.w + (b.w - a.w) * t,
	}
}

// Mat4 -- column-major, 4x4
//
// Storage is 16 contiguous f32. m[col] is a Vec4 column and the layout matches
// rl.Matrix (which stores {m0..m15} as columns), so transmute is valid
//
// Index convention used in procs: mat[col][row] via the column accessors.
// Internally we operate on the flat [16]f32 for clarity and to keep the
// hot loops branch free

Mat4 :: struct {
	// m[c*4 + r] is column c, row r
	m: [16]f32,
}

MAT4_IDENTITY :: Mat4 {
	m = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
}

mat4_identity :: proc() -> Mat4 {
	return MAT4_IDENTITY
}

mat4_at :: proc(m: Mat4, col: int, row: int) -> f32 {
	return m.m[col * 4 + row]
}

mat4_set :: proc(m: ^Mat4, col: int, row: int, v: f32) {
	m.m[col * 4 + row] = v
}

mat4_mul :: proc(a, b: Mat4) -> Mat4 {
	r: Mat4
	// Standard matrix product: result[c,r] = sum_k a[k,r] * b[c,k]
	for c in 0 ..< 4 {
		for row in 0 ..< 4 {
			acc: f32 = 0
			for k in 0 ..< 4 {
				acc += a.m[k * 4 + row] * b.m[c * 4 + k]
			}
			r.m[c * 4 + row] = acc
		}
	}
	return r
}

// Transforms a point (w=1) by m and returns the resulting Vec4
mat4_transform_point :: proc(m: Mat4, p: Vec3) -> Vec3 {
	return Vec3 {
		m.m[0] * p.x + m.m[4] * p.y + m.m[8] * p.z + m.m[12],
		m.m[1] * p.x + m.m[5] * p.y + m.m[9] * p.z + m.m[13],
		m.m[2] * p.x + m.m[6] * p.y + m.m[10] * p.z + m.m[14],
	}
}

// Transforms a direction (w=0, so translation is dropped)
mat4_transform_dir :: proc(m: Mat4, d: Vec3) -> Vec3 {
	return Vec3 {
		m.m[0] * d.x + m.m[4] * d.y + m.m[8] * d.z,
		m.m[1] * d.x + m.m[5] * d.y + m.m[9] * d.z,
		m.m[2] * d.x + m.m[6] * d.y + m.m[10] * d.z,
	}
}

mat4_transpose :: proc(m: Mat4) -> Mat4 {
	r: Mat4
	for c in 0 ..< 4 {
		for row in 0 ..< 4 {
			r.m[c * 4 + row] = m.m[row * 4 + c]
		}
	}
	return r
}

// Builds a translation matrix
mat4_translation :: proc(t: Vec3) -> Mat4 {
	return Mat4{m = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, t.x, t.y, t.z, 1}}
}

// Builds a scale matrix
mat4_scale :: proc(s: Vec3) -> Mat4 {
	return Mat4{m = {s.x, 0, 0, 0, 0, s.y, 0, 0, 0, 0, s.z, 0, 0, 0, 0, 1}}
}

// Builds a rotation matrix from a unit quaternion
mat4_from_quat :: proc(q: Quat) -> Mat4 {
	xx := q.x * q.x
	yy := q.y * q.y
	zz := q.z * q.z
	xy := q.x * q.y
	xz := q.x * q.z
	yz := q.y * q.z
	wx := q.w * q.x
	wy := q.w * q.y
	wz := q.w * q.z

	return Mat4 {
		m = {
			1 - 2 * (yy + zz),
			2 * (xy + wz),
			2 * (xz - wy),
			0,
			2 * (xy - wz),
			1 - 2 * (xx + zz),
			2 * (yz + wx),
			0,
			2 * (xz + wy),
			2 * (yz - wx),
			1 - 2 * (xx + yy),
			0,
			0,
			0,
			0,
			1,
		},
	}
}

// Composes TRS (translation * rotation * scale) in the standard game engine
// order: scale first (object space), then rotate, then translate (world space)
mat4_trs :: proc(translation: Vec3, rotation: Quat, scale: Vec3) -> Mat4 {
	t := mat4_translation(translation)
	r := mat4_from_quat(rotation)
	s := mat4_scale(scale)
	return mat4_mul(t, mat4_mul(r, s))
}

// Quat -- unit quaternion for rotation
//
// Layout: (x, y, z, w) It's layout compatible with rl.Quaternion so the renderer
// can transmute. Engine systems have to operate on the quaternion directly, not
// on Euler angles. Euler conversion lives in util.odin and is for
// user facing/tooling/Lua use only

Quat :: struct {
	x, y, z, w: f32,
}

QUAT_IDENTITY :: Quat{0, 0, 0, 1}

quat :: proc(x, y, z, w: f32) -> Quat {
	return Quat{x, y, z, w}
}

quat_identity :: proc() -> Quat {
	return QUAT_IDENTITY
}

quat_add :: proc(a, b: Quat) -> Quat {
	return Quat{a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w}
}

// Used by slerp/nlerp at the bottom; defined after quat_scale but before use
quat_sub :: proc(a, b: Quat) -> Quat {
	return Quat{a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w}
}

quat_scale :: proc(q: Quat, s: f32) -> Quat {
	return Quat{q.x * s, q.y * s, q.z * s, q.w * s}
}

quat_dot :: proc(a, b: Quat) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
}

quat_length_sq :: proc(q: Quat) -> f32 {
	return quat_dot(q, q)
}

quat_length :: proc(q: Quat) -> f32 {
	return f32(math.sqrt(f64(quat_length_sq(q))))
}

quat_normalize :: proc(q: Quat) -> Quat {
	l := quat_length(q)
	if l < EPSILON do return QUAT_IDENTITY
	inv := 1.0 / l
	return quat_scale(q, inv)
}

// Hamilton product. Order matters because: result = a * b means "apply a after b"
// in the same sense as composing rotation matrices
quat_mul :: proc(a, b: Quat) -> Quat {
	return Quat {
		x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
		w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
	}
}

quat_conjugate :: proc(q: Quat) -> Quat {
	return Quat{-q.x, -q.y, -q.z, q.w}
}

// For unit quaternions, inverse == conjugate
quat_inverse :: proc(q: Quat) -> Quat {
	n_sq := quat_length_sq(q)
	if n_sq < EPSILON do return QUAT_IDENTITY
	inv := 1.0 / n_sq
	return Quat{-q.x * inv, -q.y * inv, -q.z * inv, q.w * inv}
}

// Rotates vector v by quaternion q. Assumes q is unit
quat_rotate_vec3 :: proc(q: Quat, v: Vec3) -> Vec3 {
	// v' = q * (0,v) * q^-1, expanded (q unit so q^-1 == conjugate)
	qv := Quat{v.x, v.y, v.z, 0}
	r := quat_mul(quat_mul(q, qv), quat_conjugate(q))
	return Vec3{r.x, r.y, r.z}
}

// Builds a quaternion from a unit axis (assumed normalized by caller) and
// an angle in radians
quat_from_axis_angle_rad :: proc(axis: Vec3, angle_rad: f32) -> Quat {
	half := angle_rad * 0.5
	s := f32(math.sin(f64(half)))
	return Quat{x = axis.x * s, y = axis.y * s, z = axis.z * s, w = f32(math.cos(f64(half)))}
}

// Spherical linear interpolation. Endpoints are assumed unit; t in [0,1]
// If a and b are nearly opposite, the short arc is taken deterministically
// by flipping b's sign when dot < 0
quat_slerp :: proc(a, b: Quat, t: f32) -> Quat {
	cos_theta := quat_dot(a, b)
	bb := b
	if cos_theta < 0 {
		bb = quat_scale(b, -1)
		cos_theta = -cos_theta
	}

	// If rlly close, fall back to nlerp to avoid divide by near zero
	if cos_theta > 1.0 - EPSILON {
		return quat_normalize(quat_add(a, quat_scale(quat_sub(bb, a), t)))
	}

	theta := f32(math.acos(f64(cos_theta)))
	sin_theta := f32(math.sin(f64(theta)))
	inv := 1.0 / sin_theta
	w0 := f32(math.sin(f64((1.0 - t) * theta))) * inv
	w1 := f32(math.sin(f64(t * theta))) * inv
	return quat_add(quat_scale(a, w0), quat_scale(bb, w1))
}

// Linear interpolation + normalize
// it's actually cheaper than slerp and good for small deltas
quat_nlerp :: proc(a, b: Quat, t: f32) -> Quat {
	return quat_normalize(quat_add(a, quat_scale(quat_sub(b, a), t)))
}
