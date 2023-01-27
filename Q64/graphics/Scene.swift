import MetalKit


class Scene {
	
	var lgt = Lighting()
	var cam = Camera()
	
	var models: [Model] = []
	func add(_ model: Model) {self.models.append(model)}
	func add(_ models: [Model]) {self.models += models}
	
	func light(enc: MTLRenderCommandEncoder) {
		var cam = self.cam.proj * self.cam.view.inverse
		var lgt = self.lgt.proj * self.lgt.view.inverse
//		var eye = self.cam.pos
		var eye = self.cam.view.inverse[3].xyz
		var frg = self.lgt.lfrg
		enc.setVertexBytes(&lgt, length: util.sizeof(lgt), index: 2)
		enc.setVertexBytes(&cam, length: util.sizeof(cam), index: 3)
		enc.setFragmentBytes(&frg, length: util.sizeof(frg), index: 2)
		enc.setFragmentBytes(&eye, length: util.sizeof(eye), index: 3)
		for model in self.models {
			model.render(enc: enc)
		}
	}
	
	func shade(enc: MTLRenderCommandEncoder) {
		var lgt = self.lgt.proj * self.lgt.view.inverse
		enc.setVertexBytes(&lgt, length: util.sizeof(lgt), index: 2)
		for model in self.models {
			model.render(enc: enc)
		}
	}
	
}
