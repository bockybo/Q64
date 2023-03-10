import MetalKit


class Scene {
	
	let materials: [Material]
	init(materials: [Material]) {
		self.materials = materials
	}
	
	var models: [Model] = []
	var camera = Camera()
	var lighting = Lighting()
	
	func add(_ model: Model) {
		self.models.append(model)
	}
	func add(_ models: [Model]) {
		self.models += models
	}
	subscript(i: Int) -> Model {
		get {return self.models[i]}
		set(model) {self.models[i] = model}
	}
	
}
