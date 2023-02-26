import MetalKit


extension MDLMesh {
	
	func hasAttributeNamed(_ name: String) -> Bool {
		return self.vertexAttributeData(forAttributeNamed: name) != nil
	}
	func setVertexDescriptor(_ descr: MDLVertexDescriptor) {
		let names = descr.attributes.map {attr in (attr as! MDLVertexAttribute).name}
		let needs: (String)->(Bool) = {name in names.contains(name) && !self.hasAttributeNamed(name)}
		if needs(MDLVertexAttributeNormal) {self.addNormals(
			withAttributeNamed: MDLVertexAttributeNormal,
			creaseThreshold: 1.0
		)}
		if needs(MDLVertexAttributeTextureCoordinate) {self.addUnwrappedTextureCoordinates(
			forAttributeNamed: MDLVertexAttributeTextureCoordinate
		)}
		if needs(MDLVertexAttributeTangent) {self.addOrthTanBasis(
			forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
			normalAttributeNamed: MDLVertexAttributeNormal,
			tangentAttributeNamed: MDLVertexAttributeTangent
		)}
		self.vertexDescriptor = descr
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

extension MTLRenderCommandEncoder {
	
	func draw(submesh: MTKSubmesh, prim: MTLPrimitiveType = .triangle, iid: Int = 0, nid: Int = 1) {
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
	
	func setState(
		_ state: MTLRenderPipelineState,
		_ depth: MTLDepthStencilState,
		cull: MTLCullMode = .none
	) {
		self.setRenderPipelineState(state)
		self.setDepthStencilState(depth)
		self.setCullMode(cull)
	}
	
}
