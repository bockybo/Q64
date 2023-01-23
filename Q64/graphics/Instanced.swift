import MetalKit


class Instanced: Renderable {
	let mesh: Mesh
	var models: [Model]
	let buf: Buffer<Model.Uniform>
	
	init(_ mesh: Mesh, models: [Model]) {
		self.mesh = mesh
		self.models = models
		self.buf = Buffer<Model.Uniform>(models.count)
	}

	func render(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(lib.rstate_inst)
		for (i, model) in self.models.enumerated() {
			self.buf[i] = model.uniform
		}
		enc.setVertexBuffer(self.buf.mtl, offset: 0, index: 1)
		self.mesh.render(enc: enc, n: self.models.count)
	}

	func add(_ model: Model) {self.models.append(model)}
	func add(_ models: [Model]) {self.models += models}

}
