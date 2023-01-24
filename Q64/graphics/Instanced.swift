import MetalKit


class Instanced: Renderable {
	var meshes: [Mesh]
	var material: Material
	var instances: [Instance]
	let buffer: MTLBuffer
	
	init(instances: [Instance], material: Material = Material(), meshes: [Mesh] = []) {
		self.meshes = meshes
		self.material = material
		self.instances = instances
		self.buffer = lib.device.makeBuffer(
			length: instances.count * util.sizeof(MVtx.self),
			options: [.storageModeShared])!
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		let num = self.instances.count
		let ptr = self.buffer.contents().assumingMemoryBound(to: MVtx.self)
		for i in 0..<num {
			ptr[i] = self.instances[i].mvtx
		}
		enc.setVertexBuffer(self.buffer, offset: 0, index: 1)
		self.material.render(enc: enc)
		for mesh in self.meshes {
			mesh.render(enc: enc, num: num)
		}
	}
	
}
