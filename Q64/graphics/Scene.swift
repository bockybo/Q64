import MetalKit


class Scene: Renderable {
	
	let lights = Lights()
	
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
	var view: m4f {
		var view = m4f.idt
		view *= m4f.xrot(-self.rot.x)
		view *= m4f.yrot(-self.rot.y)
		view *= m4f.zrot(-self.rot.z)
		return view * m4f.pos(-self.pos)
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var svtx = SVtx(proj: self.proj, view: self.view)
		enc.setVertexBytes(&svtx, length: util.sizeof(svtx), index: 2)
		enc.setFragmentBuffer(self.lights.buf, offset: 0, index: 2)
		for renderable in self.renderables {
			renderable.render(enc: enc)
		}
	}
	
	private var renderables: [Renderable] = []
	func add(_ renderable: Renderable) {self.renderables.append(renderable)}
	func add(_ renderables: [Renderable]) {self.renderables += renderables}
	
}
