import MetalKit


class Instanced: Model {
	var etts: [Entity]
	var material: Material
	var meshes: [Mesh]
	let buffer: MTLBuffer
	
	init(_ etts: [Entity], material: Material = Material(), meshes: [Mesh] = []) {
		self.meshes = meshes
		self.material = material
		self.etts = etts
		self.buffer = lib.device.makeBuffer(
			length: etts.count * util.sizeof(m4f.self),
			options: [.storageModeShared])!
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		self.material.render(enc: enc)
		let num = self.etts.count
		let ptr = self.buffer.contents().assumingMemoryBound(to: m4f.self)
		for i in 0..<num {
			ptr[i] = self.etts[i].ctm
		}
		enc.setVertexBuffer(self.buffer, offset: 0, index: 1)
		for mesh in self.meshes {
			mesh.render(enc: enc, num: num)
		}
	}
	
}
