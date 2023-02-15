import MetalKit


extension MTLRenderCommandEncoder {
	
	func draw(_ mesh: MTKMesh, type: MTLPrimitiveType = .triangle, num: Int = 1) {
		for buf in mesh.vertexBuffers {
			self.setVertexBuffer(buf.buffer, offset: buf.offset, index: 0)
			for sub in mesh.submeshes {
				self.drawIndexedPrimitives(
					type:				type,
					indexCount:			sub.indexCount,
					indexType:			sub.indexType,
					indexBuffer:		sub.indexBuffer.buffer,
					indexBufferOffset:	sub.indexBuffer.offset,
					instanceCount:		num
				)
			}
		}
	}
	
}

extension MTLCommandBuffer {
	
	func pass(label: String, descr: MTLRenderPassDescriptor, _ cmds: (MTLRenderCommandEncoder)->()) {
		let enc = self.makeRenderCommandEncoder(descriptor: descr)!
		enc.label = label
		enc.pushDebugGroup(label)
		cmds(enc)
		enc.popDebugGroup()
		enc.endEncoding()
	}
	
}
