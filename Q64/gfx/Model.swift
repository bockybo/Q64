import MetalKit


class Model {
	let buf: MTLBuffer
	let entities: [Entity]
	var meshes: [MTKMesh]
	var texture: MTLTexture
	var type: MTLPrimitiveType
	var mfrg: MFRG
	
	init(
		_ entities: [Entity] = [],
		meshes: [MTKMesh] = [],
		texture: MTLTexture = lib.white1x1,
		type: MTLPrimitiveType = .triangle,
		mfrg: MFRG = MFRG()
	) {
		self.buf = lib.device.makeBuffer(
			length: entities.count * util.sizeof(MVTX.self),
			options: .storageModeShared
		)!
		self.entities = entities
		self.meshes = meshes
		self.texture = texture
		self.type = type
		self.mfrg = mfrg
	}
	
	func draw(enc: MTLRenderCommandEncoder, material: Bool) {
		if material {
			enc.setFragmentTexture(self.texture, index: 0)
			var mfrg = self.mfrg
			mfrg.render(enc: enc)
		}
		assert(self.buf.length <= self.size)
		memcpy(self.buf.contents(), self.uniforms, self.size)
		enc.setVertexBuffer(self.buf, offset: 0, index: 1)
		for mesh in self.meshes {
			enc.draw(mesh, type: self.type, num: self.entities.count)
		}
	}
	
	var uniforms: [MVTX] {return self.entities.map {$0.uniform}}
	
	var size: Int {return self.entities.count * util.sizeof(MVTX.self)}
	var cap: Int {return self.buf.length / util.sizeof(MVTX.self)}
	
}
