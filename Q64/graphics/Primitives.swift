import MetalKit


class Vtxprim: Renderable {
	let bufs: [MTKMeshBuffer]
	init(bufs: [MTKMeshBuffer]) {
		self.bufs = bufs
	}
	func render(enc: MTLRenderCommandEncoder) {
		for (i, buf) in self.bufs.enumerated() {
			enc.setVertexBuffer(buf.buffer, offset: buf.offset, index: i)
		}
	}
}

class Idxprim: Renderable {
	let subs: [MTKSubmesh]
	let type: MTLPrimitiveType
	init(subs: [MTKSubmesh], type: MTLPrimitiveType = .triangle) {
		self.subs = subs
		self.type = type
	}
	func render(enc: MTLRenderCommandEncoder) {self.render(enc: enc, n: 1)}
	func render(enc: MTLRenderCommandEncoder, n: Int) {
		for sub in self.subs {
			enc.drawIndexedPrimitives(
				type:				self.type,
				indexCount:			sub.indexCount,
				indexType:			sub.indexType,
				indexBuffer:		sub.indexBuffer.buffer,
				indexBufferOffset:	sub.indexBuffer.offset,
				instanceCount:		n
			)
		}
	}
}
