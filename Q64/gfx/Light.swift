import MetalKit


protocol Light {
	var hue: float3 {get set}
	var src: float3 {get set}
	var dir: float3 {get}
	var mag: float3 {get}
	var phi: float {get}
	var proj: float4x4 {get}
	var lgt: LGT {get}
	var shadowmap: MTLTexture? {get}
}
extension Light {
	var dir: float3 {return .z}
	var mag: float3 {return float3(1)}
	var phi: float {return 0}
	var lgt: LGT {
		let inv = .look(src: self.src, dst: self.src + self.dir) * .mag(self.mag)
		let ctm = self.proj * inv.inverse
		return .init(
			ctm: ctm,
			inv: inv,
			hue: self.hue,
			phi: self.phi
		)
	}
	var shadowmap: MTLTexture? {return nil}
}

struct Quadlight: Light {
	var hue : float3
	var src: float3
	var dst: float3
	var p0: float3
	var p1: float3
	var dir: float3 {return normalize(self.dst - self.src)}
	var proj: float4x4 {return .ortho(p0: self.p0, p1: self.p1)}
	let shadowmap: MTLTexture? = lib.tex.base(
		fmt: Renderer.fmt_shade,
		res: uint2(uint(Renderer.qshd_quad)),
		label: "shadowmaps",
		usage: [.shaderRead, .renderTarget],
		storage: .private
	)
}
struct Conelight: Light {
	var hue: float3
	var src: float3
	var dst: float3
	var rad: float
	var phi: float
	var z0: float
	var dir: float3 {return normalize(self.dst - self.src)}
	var mag: float3 {return self.rad * (tan(self.phi) * .xy + .z)}
	var proj: float4x4 {return .persp(fov: 2.5 * self.phi, z0: self.z0, z1: 2 * self.rad)}
	let shadowmap: MTLTexture? = lib.tex.base(
		fmt: Renderer.fmt_shade,
		res: uint2(uint(Renderer.qshd_cone)),
		label: "shadowmaps",
		usage: [.shaderRead, .renderTarget],
		storage: .private
	)
}
struct Icoslight: Light {
	var hue = normalize(float3(1))
	var src = float3(0, 0, 0)
	var rad: float = 1
	var mag: float3 {return float3(self.rad)}
	var proj: float4x4 {return .I} // TODO: what's the matrix for a point light ??
}


struct Lighting {
	var quad: [Quadlight] = []
	var cone: [Conelight] = []
	var icos: [Icoslight] = []
	init() {self.add_quad()}
	
	var sun: Quadlight {
		get {return self.quad[0]}
		set(sun) {self.quad[0] = sun}
	}
	
	var lights: [Light] {return self.quad + self.cone + self.icos}
	var count: Int {return self.lights.count}
	
	
	mutating func add_quad(
		hue: float3 = normalize(float3(1)),
		src: float3 = float3(0, 0, 0),
		dst: float3 = float3(0, 0, 1),
		p0: float3 = float3(-100, -100, 0.0),
		p1: float3 = float3(+100, +100, 1e3)
	) {
		self.quad.append(.init(hue: hue, src: src, dst: dst, p0: p0, p1: p1))
	}
	mutating func add_cone(
		hue: float3 = normalize(float3(1)),
		src: float3 = float3(0, 0, 0),
		dst: float3 = float3(0, 0, 1),
		rad: float = 1,
		phi: float = .pi/4,
		z0: float = 0.01
	) {
		self.cone.append(.init(hue: hue, src: src, dst: dst, rad: rad, phi: phi, z0: z0))
	}
	mutating func add_icos(
		hue: float3 = normalize(float3(1)),
		src: float3 = float3(0, 0, 0),
		rad: float = 1
	) {
		self.icos.append(.init(hue: hue, src: src, rad: rad))
	}
	
}
