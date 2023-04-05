import MetalKit


typealias float		= Float32
typealias int		= Int32
typealias short		= Int16
typealias uint		= UInt32
typealias ushort	= UInt16

extension packed_float3 {
	init(_ vec: float3) {self.init(x: vec.x, y: vec.y, z: vec.z)}
	var unpacked: float3 {return float3(self.x, self.y, self.z)}
}

extension SIMD2 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}
extension SIMD3 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}
extension SIMD4 {init(_ scalar: Scalar) {self.init(repeating: scalar)}}

func any(_ v: float3) -> Bool {return v.x != 0 || v.y != 0 || v.z != 0}
func all(_ v: float3) -> Bool {return v.x != 0 && v.y != 0 && v.z != 0}

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
			return float3x3(
				self[0].xyz,
				self[1].xyz,
				self[2].xyz)
		} set(mat3) {
			self[0].xyz = mat3[0]
			self[1].xyz = mat3[1]
			self[2].xyz = mat3[2]
		}
	}
}

extension float3 {
	static func *(lhs: float4x4, rhs: float3) -> float3 {return (lhs * float4(rhs, 1)).xyz}
	static func *(lhs: float3, rhs: float4x4) -> float3 {return rhs * lhs}
	static func *=(lhs: inout float3, rhs: float4x4) {lhs = lhs * rhs}
}

extension float4x4 {
	
	static let idt: float4x4 = matrix_identity_float4x4
	
	var pos: float3 {return  self[3].xyz}
	var dlt: float3 {return -self[2].xyz}
	var dir: float3 {return normalize(self.dlt)}
	
	var inv: float4x4 {return self.inverse}
	var T: float4x4 {return self.transpose}
	
}

extension float4x4 {
	
	static func pos(_ pos: float3) -> float4x4 {
		return float4x4(
			float4(1, 0, 0, 0),
			float4(0, 1, 0, 0),
			float4(0, 0, 1, 0),
			float4(pos, 1))
	}
	
	static func mag(_ mag: float3) -> float4x4 {
		return float4x4(
			float4(mag.x, 0, 0, 0),
			float4(0, mag.y, 0, 0),
			float4(0, 0, mag.z, 0),
			float4(0, 0, 0, 1))
	}
	
	static func rot(_ rad: float, axes: float3) -> float4x4 {
		let ct = cos(rad)
		let st = sin(rad)
		let ci = 1 - ct
		let x = axes.x
		let y = axes.y
		let z = axes.z
		return float4x4(
			float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
			float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
			float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
			float4(0, 0, 0, 1))
	}
	
	static func direct(_ f: float3, up: float3 = .y) -> float4x4 {
		let f = normalize(f)
		let s = normalize(cross(f, up))
		let u = normalize(cross(s, f))
		return float4x4(
			float4( s, 0),
			float4( u, 0),
			float4(-f, 0),
			float4(0, 0, 0, 1))
	}
	
	static func ortho(p0: float3, p1: float3) -> float4x4 {
		let sx =  2 / (p1.x - p0.x)
		let sy =  2 / (p1.y - p0.y)
		let sz = -1 / (p1.z - p0.z)
		let tx = (p0.x + p1.x) / (p0.x - p1.x)
		let ty = (p1.y + p0.y) / (p0.y - p1.y)
		let tz = p0.z / (p0.z - p1.z)
		return float4x4(float4(sx,  0,  0, 0),
						float4( 0, sy,  0, 0),
						float4( 0,  0, sz, 0),
						float4(tx, ty, tz, 1))
	}
	
	static func persp(
		z0: float,
		z1: float,
		fov: float = .pi/2,
		asp: float = 1
	) -> float4x4 {
		let y = 1 / tan(0.5 * fov)
		let x = y / asp
		let z = -z1 / (z1 - z0)
		return float4x4(
			float4(x, 0, 0, 0),
			float4(0, y, 0, 0),
			float4(0, 0, z, -1),
			float4(0, 0, z*z0, 0))
	}
	
	static func xpos(_ p: float) -> float4x4 {return .pos(float3(p, 0, 0))}
	static func ypos(_ p: float) -> float4x4 {return .pos(float3(0, p, 0))}
	static func zpos(_ p: float) -> float4x4 {return .pos(float3(0, 0, p))}
	static func xmag(_ m: float) -> float4x4 {return .mag(float3(m, 1, 1))}
	static func ymag(_ m: float) -> float4x4 {return .mag(float3(1, m, 1))}
	static func zmag(_ m: float) -> float4x4 {return .mag(float3(1, 1, m))}
	static func  mag(_ m: float) -> float4x4 {return .mag(float3(m, m, m))}
	static func xrot(_ r: float) -> float4x4 {return .rot(-r, axes: .x)}
	static func yrot(_ r: float) -> float4x4 {return .rot(-r, axes: .y)}
	static func zrot(_ r: float) -> float4x4 {return .rot(-r, axes: .z)}
	
}
