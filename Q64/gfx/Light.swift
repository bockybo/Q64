import MetalKit


// technically now that flights seperate the buffers, we don't need
// a proto for this.  however, still simplifies shader code a litle.
// TODO: separate entirely, merge w/ scene, & reorg lgt shaders.
protocol Light {
	var lgt: xlight {get}
}

struct QLight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var dst: float3 = float3(0, 0, 1)
	var dir: float3 {
		get {return normalize(self.dst - self.src)}
		set(dir) {self.dst = self.src + dir}
	}
	var w: float = 100
	var z1: float = 1e4
	var lgt: xlight {
		return xlight(
			proj: .ortho(
				p0: float3(-self.w, -self.w, 0),
				p1: float3(+self.w, +self.w, self.z1)
			),
			hue: self.hue,
			pos: self.src,
			dir: self.dir,
			rad: 1,
			phi: -1
		)
	}
}

struct CLight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var dst: float3 = float3(0, 0, 1)
	var dir: float3 {
		get {return normalize(self.dst - self.src)}
		set(dir) {self.dst = self.src + dir}
	}
	var rad: float = 1
	var phi: float = 0.25 * .pi
	var z0: float = 0.01
	var lgt: xlight {
		return xlight(
			proj: .persp(fov: 2*self.phi, z0: self.z0, z1: self.rad),
			hue: self.hue,
			pos: self.src,
			dir: self.dir,
			rad: self.rad,
			phi: self.phi
		)
	}
}
struct ILight: Light {
	var hue: float3 = normalize(float3(1))
	var src: float3 = float3(0, 0, 0)
	var rad: float = 1
	var z0: float = 0.01
	var lgt: xlight {
		return xlight(
			proj: .persp(fov: 0.5 * .pi, z0: self.z0, z1: 2*self.rad, w: false),
			hue: self.hue,
			pos: self.src,
			dir: float3(0),
			rad: self.rad,
			phi: 0
		)
	}
}
