import MetalKit


class Scene: Renderable {
	
	static let maxnlt = 64
	var lights = Buffer<Light>(Scene.maxnlt)
	
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
	
	struct Uniform {
		let ctm: m4f
		let cam: v3f
		let nlt: Int
	}
	var uniform: Uniform {
		let view = self.view
		return Uniform(
			ctm: self.proj * view,
			cam: view[3].xyz,
			nlt: self.lights.num
		)
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var uniform = self.uniform
		enc.setVertexBytes(&uniform, length: util.sizeof(uniform), index: 2)
		enc.setFragmentBuffer(self.lights.mtl, offset: 0, index: 1)
		for renderable in self.renderables {
			renderable.render(enc: enc)
		}
	}
	
	private var renderables: [Renderable] = []
	func add(_ renderable: Renderable) {self.renderables.append(renderable)}
	func add(_ renderables: [Renderable]) {self.renderables += renderables}
	
}
