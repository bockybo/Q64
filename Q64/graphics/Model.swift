import MetalKit


class Model: Renderable {
	
	var ctm: m4f = .idt
	var hue: v3f = v3f(1, 1, 1)
	var diff: f32 = 1
	var spec: f32 = 0
	var shine: f32 = 1
	
	var ett: Entity?
	init(ett: Entity? = nil) {
		self.ett = ett
	}
	
	var mvtx: ModelVtx {return ModelVtx(ctm: (self.ett?.ctm ?? .idt) * self.ctm)}
	var mfrg: ModelFrg {return ModelFrg(hue: self.hue, diff: self.diff, spec: self.spec, shine: self.shine)}
	
	func render(enc: MTLRenderCommandEncoder) {
		self.mvtx.render(enc: enc)
		self.mfrg.render(enc: enc)
		for mesh in self.meshes {
			mesh.render(enc: enc)
		}
	}
	
	private var meshes: [Mesh] = []
	func add(_ mesh: Mesh) {self.meshes.append(mesh)}
	func add(_ meshes: [Mesh]) {self.meshes += meshes}
	
}


struct ModelVtx: Renderable {
	let ctm: m4f
	func render(enc: MTLRenderCommandEncoder) {
		var mvtx = self
		enc.setVertexBytes(&mvtx, length: util.sizeof(ModelVtx.self), index: 1)
	}
}

struct ModelFrg: Renderable {
	let hue: v3f
	let diff: f32
	let spec: f32
	let shine: f32
	func render(enc: MTLRenderCommandEncoder) {
		var mfrg = self
		enc.setFragmentBytes(&mfrg, length: util.sizeof(ModelFrg.self), index: 1)
	}
}
