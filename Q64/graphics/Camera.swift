import MetalKit


struct Camera {
	
	var proj: m4f = .idt
	var aspect: f32 = 1 {
		didSet {
			self.proj = m4f.proj(
				fov: Config.fov,
				aspect: self.aspect,
				z0: Config.z0,
				z1: Config.z1
			)
		}
	}
	
	var pos = v3f(0, 0, 0)
	var rot = v3f(0, 0, 0)
	var mag = v3f(1, 1, 1)
	var view: m4f {
		var view = m4f.pos(self.pos) * m4f.mag(self.mag)
		view *= m4f.zrot(self.rot.z)
		view *= m4f.yrot(self.rot.y)
		view *= m4f.xrot(self.rot.x)
		return view
	}
	
}
