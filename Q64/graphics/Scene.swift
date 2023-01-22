import MetalKit


class Scene: Renderable {
	
	var lights: Buffer<Light>
	init(_ device: MTLDevice, nlight: Int) {
		self.lights = Buffer<Light>(device, mode: .frg, arg: 3, cap: nlight)
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
	
	var svtx: SceneVtx {return SceneVtx(ctm: self.proj * self.view)}
	var sfrg: SceneFrg {return SceneFrg(cam: self.view[3].xyz, nlt: self.lights.num)}
	
	func render(enc: MTLRenderCommandEncoder) {
		self.svtx.render(enc: enc)
		self.sfrg.render(enc: enc)
		enc.setFragmentBuffer(self.lights.buf, offset: 0, index: 3)
		for renderable in self.renderables {
			renderable.render(enc: enc)
		}
	}
	
	private var renderables: [Renderable] = []
	func add(_ renderable: Renderable) {self.renderables.append(renderable)}
	func add(_ renderables: [Renderable]) {self.renderables += renderables}
	
}


struct SceneVtx: Renderable {
	let ctm: m4f
	func render(enc: MTLRenderCommandEncoder) {
		var svtx = self
		enc.setVertexBytes(&svtx, length: util.sizeof(SceneVtx.self), index: 2)
	}
	
}
struct SceneFrg: Renderable {
	let cam: v3f
	let nlt: Int
	func render(enc: MTLRenderCommandEncoder) {
		var sfrg = self
		enc.setFragmentBytes(&sfrg, length: util.sizeof(SceneFrg.self), index: 2)
	}
	
}
