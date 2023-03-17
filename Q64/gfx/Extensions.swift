import MetalKit


extension MTLBuffer {
	func write(_ src: UnsafeRawPointer, length: Int) {
		assert(length <= self.length)
		memcpy(self.contents(), src, length)
		if self.storageMode == .managed {self.didModifyRange(0..<length)}
	}
}

extension MTLCommandQueue {
	func commit(label: String, _ cmds: (MTLCommandBuffer)->()) {
		guard let buf = self.makeCommandBuffer() else {
			fatalError("Couldn't make command buffer for label: \(label)")
		}
		buf.label = label
		cmds(buf)
		buf.commit()
	}
}
extension MTLCommandBuffer {
	func pass(label: String, descr: MTLRenderPassDescriptor, _ cmds: (MTLRenderCommandEncoder)->()) {
		guard let enc = self.makeRenderCommandEncoder(descriptor: descr) else {
			fatalError("Couldn't make render command encoder for label: \(label)")
		}
		enc.label = label
		enc.pushDebugGroup(label)
		cmds(enc)
		enc.popDebugGroup()
		enc.endEncoding()
	}
}

extension MTLRenderCommandEncoder {
	
	func draw(_ submesh: MTKSubmesh, iid: Int = 0, nid: Int = 1) {
		if (nid == 0) {return}
		assert(nid > 0) // shouldn't metal assert this??
		self.drawIndexedPrimitives(
			type:				.triangle,
			indexCount:			submesh.indexCount,
			indexType:			submesh.indexType,
			indexBuffer:		submesh.indexBuffer.buffer,
			indexBufferOffset:	submesh.indexBuffer.offset,
			instanceCount:		nid,
			baseVertex:			0,
			baseInstance: 		iid
		)
	}
	func draw(_ mesh: MTKMesh, iid: Int = 0, nid: Int = 1) {
		for buf in mesh.vertexBuffers {
			self.setVBuffer(buf.buffer, offset: buf.offset, index: 0)
			self.draw(mesh.submeshes, iid: iid, nid: nid)
		}
		self.unsetVBuffer(index: 0)
	}
	func draw(_ submeshes: [MTKSubmesh], iid: Int = 0, nid: Int = 1) {
		for submesh in submeshes {self.draw(submesh, iid: iid, nid: nid)}
	}
	func draw(_ meshes: [MTKMesh], iid: Int = 0, nid: Int = 1) {
		for mesh in meshes {self.draw(mesh, iid: iid, nid: nid)}
	}
	
	
	func setVBuffer(_ buf: MTLBuffer?, offset: Int = 0, index: Int) {
		self.setVertexBuffer(buf, offset: offset, index: index)
	}
	func setFBuffer(_ buf: MTLBuffer?, offset: Int = 0, index: Int) {
		self.setFragmentBuffer(buf, offset: offset, index: index)
	}
	func setTBuffer(_ buf: MTLBuffer?, offset: Int = 0, index: Int) {
		self.setTileBuffer(buf, offset: offset, index: index)
	}
	func unsetVBuffer(index: Int) {self.setVBuffer(nil, index: index)}
	func unsetFBuffer(index: Int) {self.setFBuffer(nil, index: index)}
	func unsetTBuffer(index: Int) {self.setTBuffer(nil, index: index)}
	
	func setVBytes<T>(_ bytes: UnsafePointer<T>, count: Int = 1, index: Int) {
		self.setVertexBytes(bytes, length: count * sizeof(T.self), index: index)
	}
	func setFBytes<T>(_ bytes: UnsafePointer<T>, count: Int = 1, index: Int) {
		self.setFragmentBytes(bytes, length: count * sizeof(T.self), index: index)
	}
	func setTBytes<T>(_ bytes: UnsafePointer<T>, count: Int = 1, index: Int) {
		self.setTileBytes(bytes, length: count * sizeof(T.self), index: index)
	}
	
//	obvi tmp, just makes draw() more readable for dev
	func setStates(ps: MTLRenderPipelineState, ds: MTLDepthStencilState? = nil) {
		self.setRenderPipelineState(ps)
		if let ds = ds {self.setDepthStencilState(ds)}
	}
	func setCull(mode: MTLCullMode? = nil, wind: MTLWinding? = nil) {
		if let mode = mode {self.setCullMode(mode)}
		if let wind = wind {self.setFrontFacing(wind)}
	}
	
}

extension MTLFunction {
	
	// this is dumb but you need the ref like what are you supposed to do
	func makeArgumentEncoder(
		bufferIndex: Int,
		bufferOptions: MTLResourceOptions = .storageModePrivate
	) -> (arg: MTLArgumentEncoder, buf: MTLBuffer) {
		let arg = self.makeArgumentEncoder(bufferIndex: bufferIndex)
		let buf = util.buffer(len: arg.encodedLength, opt: bufferOptions)
		arg.setArgumentBuffer(buf, offset: 0)
		return (arg: arg, buf: buf)
	}
	
}
extension MTLArgumentEncoder {
	
	func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
		self.constantData(at: index).copyMemory(from: bytes, byteCount: length)
	}
	
}
