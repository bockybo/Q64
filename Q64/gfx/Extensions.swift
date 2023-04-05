import MetalKit


extension MTLBuffer {
	func write(_ src: UnsafeRawPointer, length: Int, offset: Int = 0) {
		assert(length + offset <= self.length)
		memcpy(self.contents() + offset, src, length)
		if self.storageMode == .managed {self.didModifyRange(length..<length+offset)}
	}
	func write<T>(_ src: UnsafePointer<T>, count: Int = 1, start: Int = 0) {
		self.write(src, length: count * sizeof(T.self), offset: start * sizeof(T.self))
	}
	func write<T>(_ src: [T], start: Int = 0) {
		self.write(src, count: src.count, start: start)
	}
	func didModifyAll() {self.didModifyRange(0..<self.length)}
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
	
	func draw(_ n: Int, iid: Int = 0, nid: Int = 1, vid: Int = 0) {
		if (nid == 0) {return}
		assert(nid > 0)
		self.drawPrimitives(
			type:			.triangle,
			vertexStart:	vid,
			vertexCount:	n,
			instanceCount:	nid,
			baseInstance:	iid
		)
	}
	func draw(_ submesh: MTKSubmesh, iid: Int = 0, nid: Int = 1, vid: Int = 0) {
		if (nid == 0) {return}
		assert(nid > 0) // shouldn't metal assert this??
		self.drawIndexedPrimitives(
			type:				.triangle,
			indexCount:			submesh.indexCount,
			indexType:			submesh.indexType,
			indexBuffer:		submesh.indexBuffer.buffer,
			indexBufferOffset:	submesh.indexBuffer.offset,
			instanceCount:		nid,
			baseVertex:			vid,
			baseInstance: 		iid
		)
	}
	func draw(_ mesh: MTKMesh, iid: Int = 0, nid: Int = 1) {
		assert(mesh.vertexBuffers.count == 1) // what are u supposed to do?
		let buf = mesh.vertexBuffers[0]
		self.setVBuffer(buf.buffer, offset: buf.offset, index: 0)
		for submesh in mesh.submeshes {
			self.draw(submesh, iid: iid, nid: nid)
		}
		self.unsetVBuffer(index: 0)
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
	
	func setPS(_ ps: MTLRenderPipelineState) {return self.setRenderPipelineState(ps)}
	func setDS(_ ds: MTLDepthStencilState) {return self.setDepthStencilState(ds)}
	
	func setAmplification(count: Int) {
		self.setVertexAmplificationCount(count, viewMappings: nil)
	}
	func setAmplification(viewports: [Int] = [], targets: [Int] = []) {
		let count = max(viewports.count, targets.count)
		assert(count >= 1)
		let viewports = viewports + .init(repeating: 0, count: viewports.count - count)
		let targets = targets + .init(repeating: 0, count: targets.count - count)
		let maps = (0..<count).map {i in MTLVertexAmplificationViewMapping(
			viewportArrayIndexOffset: (i < viewports.count) ? uint(viewports[i]) : 0,
			renderTargetArrayIndexOffset: (i < targets.count) ? uint(targets[i]) : 0)}
		self.setVertexAmplificationCount(count, viewMappings: maps)
	}
	func unsetAmplification() {self.setAmplification(count: 1)}
	
}

struct ArgumentBuffer {
	let enc: MTLArgumentEncoder
	let buf: MTLBuffer
}
extension MTLFunction {
	func makeArgumentBuffer(
		at index: Int,
		options: MTLResourceOptions = .storageModeShared
	) -> ArgumentBuffer {
		let enc = self.makeArgumentEncoder(bufferIndex: index)
		let buf = util.buffer(length: enc.encodedLength, options: options)
		enc.setArgumentBuffer(buf, offset: 0)
		return ArgumentBuffer(enc: enc, buf: buf)
	}
}
extension MTLArgumentEncoder {
	func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
		self.constantData(at: index).copyMemory(from: bytes, byteCount: length)
	}
	func setBytes<T>(_ bytes: UnsafePointer<T>, count: Int = 1, index: Int) {
		self.setBytes(bytes, length: count * sizeof(T.self), index: index)
	}
}
