import MetalKit


class Model: Renderable {
	var meshes: [Mesh]
	var material: Material
	var instance: Instance
	
	init(instance: Instance, material: Material = Material(), meshes: [Mesh] = []) {
		self.meshes = meshes
		self.material = material
		self.instance = instance
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var mvtx = self.instance.mvtx
		enc.setVertexBytes(&mvtx, length: util.sizeof(mvtx), index: 1)
		self.material.render(enc: enc)
		for mesh in self.meshes {
			mesh.render(enc: enc)
		}
	}
	
}
