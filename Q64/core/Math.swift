import MetalKit


typealias float = Float32
typealias float2 = SIMD2<float>
typealias float3 = SIMD3<float>
typealias float4 = SIMD4<float>

typealias uint = UInt32
typealias uint2 = SIMD2<uint>
typealias uint3 = SIMD3<uint>
typealias uint4 = SIMD4<uint>

typealias float3x3 = simd_float3x3
typealias float4x4 = simd_float4x4


extension SIMD2 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}
extension SIMD3 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}
extension SIMD4 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}


extension float3 {
	static let x = float3(1, 0, 0)
	static let y = float3(0, 1, 0)
	static let z = float3(0, 0, 1)
	static let xy = float3(1, 1, 0)
	static let xz = float3(1, 0, 1)
	static let yz = float3(0, 1, 1)
	var xz: float2 {
		get {return float2(self.x, self.z)}
		set(vec2) {self.x = vec2.x; self.z = vec2.y}
	}
	var xy: float2 {
		get {return float2(self.x, self.y)}
		set(vec2) {self.x = vec2.x; self.y = vec2.y}
	}
	var yz: float2 {
		get {return float2(self.y, self.z)}
		set(vec2) {self.y = vec2.x; self.z = vec2.y}
	}
}
extension float4 {
	var xyz: float3 {
		get {return .init(self.x, self.y, self.z)}
		set(vec3) {
			self.x = vec3.x
			self.y = vec3.y
			self.z = vec3.z
		}
	}
}
extension float4x4 {
	var xyz: float3x3 {
		get {
			return .init(
				self[0].xyz,
				self[1].xyz,
				self[2].xyz)
		} set(mat3) {
			self[0].xyz = mat3[0]
			self[1].xyz = mat3[1]
			self[2].xyz = mat3[2]
		}
	}
	static func *(lhs: float4x4, rhs: float3) -> float3 {
		return (lhs * float4(rhs, 1)).xyz
	}
}


extension float3x3 {
	static let I: float3x3 = matrix_identity_float3x3
}

extension float4x4 {
	static let I: float4x4 = matrix_identity_float4x4
	
	var pos: float3 {return  self[3].xyz}
	var dlt: float3 {return -self[2].xyz}
	var dir: float3 {return normalize(self.dlt)}
	
	var inv: float4x4 {return self.inverse}
	var T: float4x4 {return self.transpose}
	
	
	static func pos(_ pos: float3) -> float4x4 {return .tf {
		$0[3].xyz = pos
	}}
	
	static func mag(_ mag: float3) -> float4x4 {return .tf {
		$0[0].x = mag.x
		$0[1].y = mag.y
		$0[2].z = mag.z
	}}
	
	static func xrot(_ rad: float) -> float4x4 {return .tf {
		let x = cos(rad), y = sin(rad)
		$0[1].xyz = float3(0, +x, -y)
		$0[2].xyz = float3(0, +y, +x)
	}}
	static func yrot(_ rad: float) -> float4x4 {return .tf {
		let x = cos(rad), y = sin(rad)
		$0[0].xyz = float3(+x, 0, +y)
		$0[2].xyz = float3(-y, 0, +x)
	}}
	static func zrot(_ rad: float) -> float4x4 {return .tf {
		let x = cos(rad), y = sin(rad)
		$0[0].xyz = float3(+x, -y, 0)
		$0[1].xyz = float3(+y, +x, 0)
	}}
	
	static func rot(_ rad: float, axes: float3) -> float4x4 {return .tf {
		let ct = cos(rad)
		let st = sin(rad)
		let ci = 1 - ct
		let x = axes.x
		let y = axes.y
		let z = axes.z
		$0[0].xyz = float3(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st)
		$0[1].xyz = float3(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st)
		$0[2].xyz = float3(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci)
	}}
	
	static func look(src: float3, dst: float3, up: float3 = .y) -> float4x4 {return .tf {
		let f = normalize(dst - src)
		let s = normalize(cross(f, up))
		let u = normalize(cross(s, f))
		$0[0].xyz = s
		$0[1].xyz = u
		$0[2].xyz = -f
		$0[3].xyz = src
	}}
	
	static func persp(fov: float, asp: float = 1, z0: float, z1: float) -> float4x4 {return .tf {
		let y = 1 / tan(0.5 * fov)
		let x = y / asp
		let z = z1 / (z0 - z1)
		let w = z * z0
		$0 = .mag(float3(x, y, z))
		$0[2].w = -1
		$0[3].z =  w
	}}
	
	static func ortho(p0: float3, p1: float3) -> float4x4 {
		let m = float4x4.mag(float3(2, 2, -1) / (p1 - p0))
		let t = float4x4.pos(float3(1, 1,  0) * (p1 + p0) * -0.5)
		return m * t
	}
	
	
	static func xpos(_ p: float) -> float4x4 {return .pos(float3(p, 0, 0))}
	static func ypos(_ p: float) -> float4x4 {return .pos(float3(0, p, 0))}
	static func zpos(_ p: float) -> float4x4 {return .pos(float3(0, 0, p))}
	static func xmag(_ m: float) -> float4x4 {return .mag(float3(m, 1, 1))}
	static func ymag(_ m: float) -> float4x4 {return .mag(float3(1, m, 1))}
	static func zmag(_ m: float) -> float4x4 {return .mag(float3(1, 1, m))}
	static func  mag(_ m: float) -> float4x4 {return .mag(float3(m, m, m))}
	
	
	private static func tf(_ f: (inout float4x4)->()) -> float4x4 {
		var ctm = float4x4.I
		f(&ctm)
		return ctm
	}
	
}
