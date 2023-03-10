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
	
	func draw(submesh: MTKSubmesh, prim: MTLPrimitiveType = .triangle, iid: Int = 0, nid: Int = 1) {
		if (nid == 0) {return}
		assert(nid > 0) // shouldn't metal assert this??
		self.drawIndexedPrimitives(
			type:				prim,
			indexCount:			submesh.indexCount,
			indexType:			submesh.indexType,
			indexBuffer:		submesh.indexBuffer.buffer,
			indexBufferOffset:	submesh.indexBuffer.offset,
			instanceCount:		nid,
			baseVertex:			0,
			baseInstance: 		iid
		)
	}
	func draw(mesh: MTKMesh, prim: MTLPrimitiveType = .triangle, iid: Int = 0, nid: Int = 1) {
		for buf in mesh.vertexBuffers {
			self.setVertexBuffer(buf.buffer, offset: buf.offset, index: 0)
			for sub in mesh.submeshes {
				self.draw(submesh: sub, prim: prim, iid: iid, nid: nid)
			}
		}
	}
	
	func setVBuffer(_ buf: MTLBuffer?, index: Int) {self.setVertexBuffer(buf, offset: 0, index: index)}
	func setFBuffer(_ buf: MTLBuffer?, index: Int) {self.setFragmentBuffer(buf, offset: 0, index: index)}
	
//	obvi tmp, just makes draw() more readable for dev
	func setStates(ps: MTLRenderPipelineState, ds: MTLDepthStencilState) {
		self.setRenderPipelineState(ps)
		self.setDepthStencilState(ds)
	}
	func setCull(mode: MTLCullMode, wind: MTLWinding) {
		self.setCullMode(mode)
		self.setFrontFacing(wind)
	}
	
}

extension MTLArgumentEncoder {
	
	func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
		self.constantData(at: index).copyMemory(from: bytes, byteCount: length)
	}
	
}
