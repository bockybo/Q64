import MetalKit


class Instances: Renderable {
	let mesh: Mesh
	var models: [Model]
	
	init(mesh: Mesh, models: [Model] = []) {
		self.mesh = mesh
		self.models = models
	}

	func render(enc: MTLRenderCommandEncoder) {
		self.mesh.vtxprim.render(enc: enc)
		for model in self.models {
			model.render(enc: enc)
			self.mesh.idxprim.render(enc: enc)
		}
	}
	
	func add(_ model: Model) {self.models.append(model)}
	func add(_ models: [Model]) {self.models += models}

}
