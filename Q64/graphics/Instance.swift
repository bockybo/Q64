import MetalKit


class Instance: Model {
	var ett: Entity
	var material: Material
	var meshes: [Mesh]
	
	init(_ ett: Entity, material: Material = Material(), meshes: [Mesh] = []) {
		self.ett = ett
		self.material = material
		self.meshes = meshes
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		self.material.render(enc: enc)
		var ctm = self.ett.ctm
		enc.setVertexBytes(&ctm, length: util.sizeof(ctm), index: 1)
		for mesh in self.meshes {
			mesh.render(enc: enc)
		}
	}
	
}
