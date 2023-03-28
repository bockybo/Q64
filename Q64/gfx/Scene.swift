import MetalKit


class Scene {
	
	let materials: [Material]
	init(materials: [Material]) {
		self.materials = materials
	}
	
	var models: [Model] = []
	var camera = Camera()
	
	var sun = QLight()
	var clights: [CLight] = []
	var ilights: [ILight] = []
	
	var lights: [Light] {
		return [self.sun] + self.clights + self.ilights
	}
	
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
	
	var scn: xscene {
		return xscene(
			cam: self.camera.cam,
			nlgt: uint(self.lights.count),
			nclgt: uint(self.clights.count),
			nilgt: uint(self.ilights.count)
		)
	}
	
}
