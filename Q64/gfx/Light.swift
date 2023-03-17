import MetalKit


// technically now that flights seperate the buffers, we don't need
// a proto for this.  however, still simplifies shader code a litle.
// TODO: separate entirely, merge w/ scene, & reorg lgt shaders.
protocol Light {
	var hue: float3 {get set}
	var src: float3 {get set}
	var dir: float3 {get}
	var mag: float3 {get}
	var phi: float {get}
	var proj: float4x4 {get}
	var view: float4x4 {get}
	var lgt: LGT {get}
}
extension Light {
	var dir: float3 {return .z}
	var mag: float3 {return float3(1)}
	var view: float4x4 {
		return .look(dir: self.dir, src: self.src) * .mag(self.mag)
	}
	var lgt: LGT {
		let proj = self.proj
		let view = self.view
		return .init(
			proj: proj,
			view: view,
			invproj: proj.inverse,
			invview: view.inverse,
			hue: self.hue,
			phi: self.phi
		)
	}
}

struct QLight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var dst: float3 = float3(0, 0, 1)
	var p0: float3 = float3(-100, -100, 0.0)
	var p1: float3 = float3(+100, +100, 1e3)
	var phi: float {return -1}
	var dir: float3 {return normalize(self.dst - self.src)}
	var proj: float4x4 {return .ortho(p0: self.p0, p1: self.p1)}
}
struct CLight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var dst: float3 = float3(0, 0, 1)
	var rad: float = 1
	var phi: float = .pi/4
	var z0: float = 0.01
	var dir: float3 {return normalize(self.dst - self.src)}
	var mag: float3 {return float3(self.rad)}
	var proj: float4x4 {return .persp(fov: 2*self.phi, z0: self.z0, z1: 2*self.rad)}
}
struct ILight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var rad: float = 1
	var phi: float {return 0}
	var mag: float3 {return float3(self.rad)}
	var proj: float4x4 {return .I} // TODO: what's the matrix for a point light ??
}
