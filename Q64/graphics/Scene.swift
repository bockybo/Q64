import MetalKit


class Scene: Renderable {
	
	var lights: Lights
	init(_ device: MTLDevice, nlight: Int) {
		self.lights = Lights(device, mode: .frg, arg: 3, cap: nlight)
	}
	
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
		var ctm = self.proj * self.view
		var cam = self.view[3].xyz
		enc.setVertexBytes(&ctm, length: util.sizeof(m4f.self), index: 2)
		enc.setFragmentBytes(&cam, length: util.sizeof(v3f.self), index: 2)
		self.lights.render(enc: enc)
		for renderable in self.renderables {
			renderable.render(enc: enc)
		}
	}
	
	private var renderables: [Renderable] = []
	func add(_ renderable: Renderable) {self.renderables.append(renderable)}
	func add(_ renderables: [Renderable]) {self.renderables += renderables}
	
}
