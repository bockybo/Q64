import simd


typealias float = Float32
typealias float2 = simd_float2
typealias float3 = simd_float3
typealias float4 = simd_float4
typealias float4x4 = simd_float4x4

typealias uint = UInt32
typealias uint2 = simd_uint2
typealias uint3 = simd_uint3


extension float2 {
	init(_ z: float) {self.init(z, z)}
	
	static func rot(_ rot: float) -> float2 {return .init(cos(rot), sin(rot))}
	
}

extension float3 {
	init(_ w: float) {self.init(w, w, w)}
	
	var xy: float2 {return simd_make_float2(self)}
	
	static let x = float3(1, 0, 0)
	static let y = float3(0, 1, 0)
	static let z = float3(0, 0, 1)
	
}

extension float4 {
	var xy: float2 {return simd_make_float2(self)}
	var xyz: float3 {return simd_make_float3(self)}
}

extension float4x4 {
	static let idt: float4x4 = matrix_identity_float4x4
	
	static func pos(_ pos: float3) -> float4x4 {
		return .init(
			float4(1, 0, 0, 0),
			float4(0, 1, 0, 0),
			float4(0, 0, 1, 0),
			float4(pos, 1))
	}
	
	static func mag(_ mag: float3) -> float4x4 {
		return .init(
			float4(mag.x, 0, 0, 0),
			float4(0, mag.y, 0, 0),
			float4(0, 0, mag.z, 0),
			float4(0, 0, 0, 1))
	}
	
	static func xrot(_ dir: float2) -> float4x4 {
		return .init(
			float4(1, 0, 0, 0),
			float4(0, +dir.x, -dir.y, 0),
			float4(0, +dir.y, +dir.x, 0),
			float4(0, 0, 0, 1)
		)
	}
	static func yrot(_ dir: float2) -> float4x4 {
		return .init(
			float4(+dir.x, 0, +dir.y, 0),
			float4(0, 1, 0, 0),
			float4(-dir.y, 0, +dir.x, 0),
			float4(0, 0, 0, 1)
		)
	}
	static func zrot(_ dir: float2) -> float4x4 {
		return .init(
			float4(+dir.x, -dir.y, 0, 0),
			float4(+dir.y, +dir.x, 0, 0),
			float4(0, 0, 1, 0),
			float4(0, 0, 0, 1)
		)
	}
	static func xrot(_ rot: float) -> float4x4 {return .xrot(float2.rot(rot))}
	static func yrot(_ rot: float) -> float4x4 {return .yrot(float2.rot(rot))}
	static func zrot(_ rot: float) -> float4x4 {return .zrot(float2.rot(rot))}
	
	static func look(dst: float3, src: float3, u: float3 = .y) -> float4x4 {
		let f = normalize(dst - src)
		let s = normalize(cross(f, u))
		let u = normalize(cross(s, f))
		return .init(
			float4(  s, 0),
			float4(  u, 0),
			float4( -f, 0),
			float4(src, 1))
	}
	
	static func proj(fov: float, aspect: float, z0: float, z1: float) -> float4x4 {
		let y = 1 / tan(0.5 * fov)
		let x = y / aspect
		let z = z1 / (z0 - z1)
		let w = z * z0
		return .init(
			float4(x, 0, 0,  0),
			float4(0, y, 0,  0),
			float4(0, 0, z, -1),
			float4(0, 0, w,  0))
	}
	
	static func orth(p0: float3, p1: float3) -> float4x4 {
		let m = float3(2, 2, -1) / (p1 - p0)
		let t = float3(1, 1,  0) * (p1 + p0) * -0.5
		return .pos(t) * .mag(m)
	}

}
