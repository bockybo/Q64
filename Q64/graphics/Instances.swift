import MetalKit


class Instances: Renderable {
	let rstate: MTLRenderPipelineState
	let buf: MTLBuffer
	let mesh: Mesh
	var models: [Model]

	init(_ device: MTLDevice, mesh: Mesh, models: [Model]) {
		self.rstate = lib.rstate_inst(device)
		self.mesh = mesh
		self.models = models
		self.buf = device.makeBuffer(
			length: util.sizeof(ModelVtx.self) * models.count,
			options: [.storageModeShared]
		)!
	}

	func render(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.rstate)
		
		// TODO:  can instance frgfns? otherwise move uniforms to vtx

		let ptr = self.buf.contents().assumingMemoryBound(to: ModelVtx.self)
		for (i, model) in self.models.enumerated() {
			ptr[i] = model.mvtx
//			model.mfrg.render(enc: enc)
		}
		self.models[0].mfrg.render(enc: enc) // tmp
		enc.setVertexBuffer(self.buf, offset: 0, index: 1)
		self.mesh.render(enc: enc, n: self.models.count)

	}

	func add(_ model: Model) {self.models.append(model)}
	func add(_ models: [Model]) {self.models += models}

}
