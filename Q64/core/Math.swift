import simd


typealias f32 = Float32
typealias v2f = simd_float2
typealias v3f = simd_float3
typealias v4f = simd_float4
typealias m4f = simd_float4x4


extension v3f {
	
	static let x = v3f(1, 0, 0)
	static let y = v3f(0, 1, 0)
	static let z = v3f(0, 0, 1)
}

extension v4f {
	var xyz: v3f {return simd_make_float3(self)}
}

extension m4f {
	static let idt: m4f = matrix_identity_float4x4
	
	static func *(lhs: m4f, rhs: v3f) -> v3f {return matrix_multiply(lhs, v4f(rhs, 1)).xyz}
	static func *(lhs: v3f, rhs: m4f) -> v3f {return matrix_multiply(v4f(lhs, 1), rhs).xyz}
	static func *=(lhs: inout v3f, rhs: m4f) {lhs = lhs * rhs}
	
	static func pos(_ pos: v3f) -> m4f {
		let x = pos.x
		let y = pos.y
		let z = pos.z
		return m4f(
			v4f(1, 0, 0, 0),
			v4f(0, 1, 0, 0),
			v4f(0, 0, 1, 0),
			v4f(x, y, z, 1))
	}
	
	static func mag(_ mag: v3f) -> m4f {
		let x = mag.x
		let y = mag.y
		let z = mag.z
		return m4f(
			v4f(x, 0, 0, 0),
			v4f(0, y, 0, 0),
			v4f(0, 0, z, 0),
			v4f(0, 0, 0, 1))
	}
	
	static func rot(_ rot: f32, axes: v3f) -> m4f {
		let x = axes.x
		let y = axes.y
		let z = axes.z
		let c = cos(rot)
		let s = sin(rot)
		let mc = 1 - c
		return m4f(
			v4f(x * x * mc + c,     x * y * mc + z * s, x * z * mc - y * s, 0),
			v4f(y * x * mc - z * s, y * y * mc + c,     y * z * mc + x * s, 0),
			v4f(z * x * mc + y * s, z * y * mc - x * s, z * z * mc + c,     0),
			v4f(0, 0, 0, 1))
	}
	
	static func mag(_ mag: f32) -> m4f {return m4f.mag(v3f(mag, mag, mag))}
	static func xrot(_ rot: f32) -> m4f {return m4f.rot(rot, axes: .x)}
	static func yrot(_ rot: f32) -> m4f {return m4f.rot(rot, axes: .y)}
	static func zrot(_ rot: f32) -> m4f {return m4f.rot(rot, axes: .z)}
	
	static func proj(fov: f32, aspect: f32, z0: f32, z1: f32) -> m4f {
		let y = 1 / tan(0.5 * fov)
		let x = y / aspect
		let z = z1 / (z0 - z1)
		let w = z * z0
		return m4f(
			v4f(x, 0, 0,  0),
			v4f(0, y, 0,  0),
			v4f(0, 0, z, -1),
			v4f(0, 0, w,  0))
	}
	
	static func look(dst: v3f, src: v3f, up: v3f = .y) -> m4f {
		let f = normalize(dst - src)
		let s = normalize(cross(f, up))
		let u = normalize(cross(s, f))
		return m4f(
			v4f(  s, 0),
			v4f(  u, 0),
			v4f( -f, 0),
			v4f(src, 1))
	}
	
	static func orth(p0: v3f, p1: v3f) -> m4f {
		let m = v3f(2, 2, -1) / (p1 - p0)
		let t = v3f(1, 1,  0) * (p1 + p0)
		return m4f.pos(-0.5 * t) * m4f.mag(m)
	}
	
}
