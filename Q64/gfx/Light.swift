import MetalKit


protocol Light {
	var lgt: xlight {get}
}

struct QLight: Light {
	var hue: float3 = normalize(float3(1))
	var dir: float3 = float3(0, 0, 1)
	var w: float = 100
	var z1: float = 1e4
	var lgt: xlight {
		return xlight(
			proj: .ortho(
				p0: float3(-self.w, -self.w, 0),
				p1: float3(+self.w, +self.w, self.z1)
			),
			hue: self.hue,
			pos: float3(0),
			dir: normalize(self.dir),
			rad: 1,
			phi: -1
		)
	}
}

struct CLight: Light {
	var hue: float3 = normalize(float3(1))
	var pos: float3 = float3(0, 0, 0)
	var dir: float3 = float3(0, 0, 1)
	var rad: float = 1
	var phi: float = 0.25 * .pi
	var z0: float = 0.01
	var lgt: xlight {
		return xlight(
			proj: .persp(z0: self.z0, z1: 2*self.rad, fov: 2*self.phi),
			hue: self.hue,
			pos: self.pos,
			dir: normalize(self.dir),
			rad: self.rad,
			phi: self.phi
		)
	}
}

struct ILight: Light {
	var hue: float3 = normalize(float3(1))
	var pos: float3 = float3(0, 0, 0)
	var rad: float = 1
	var z0: float = 0.01
	var lgt: xlight {
		return xlight(
			proj: .persp(z0: self.z0, z1: 2*self.rad),
			hue: self.hue,
			pos: self.pos,
			dir: float3(0),
			rad: self.rad,
			phi: 0
		)
	}
}
