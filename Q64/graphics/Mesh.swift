import MetalKit


class Mesh {
	let mesh: MTKMesh
	let type: MTLPrimitiveType
	
	init(_ mesh: MTKMesh, type: MTLPrimitiveType) {
		self.mesh = mesh
		self.type = type
	}
	
	func render(enc: MTLRenderCommandEncoder) {self.render(enc: enc, num: 1)}
	func render(enc: MTLRenderCommandEncoder, num: Int) {
		for (i, buf) in self.mesh.vertexBuffers.enumerated() {
			enc.setVertexBuffer(buf.buffer, offset: buf.offset, index: i)
		}
		for sub in self.mesh.submeshes {
			enc.drawIndexedPrimitives(
				type:				self.type,
				indexCount:			sub.indexCount,
				indexType:			sub.indexType,
				indexBuffer:		sub.indexBuffer.buffer,
				indexBufferOffset:	sub.indexBuffer.offset,
				instanceCount:		num
			)
		}
	}
	
	convenience init(_ mesh: MDLMesh, type: MTLPrimitiveType = .triangle) {
		mesh.vertexDescriptor = lib.vtxdescr
		mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)
		let mesh = try! MTKMesh(mesh: mesh, device: lib.device)
		self.init(mesh, type: type)
	}
	
	
	static let bufalloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func load(path: String, type: MTLPrimitiveType = .triangle) -> [Mesh] {
		let url = util.url(path)!
		let asset = MDLAsset(
			url: url,
			vertexDescriptor: lib.vtxdescr,
			bufferAllocator: Mesh.bufalloc
		)
		let mdlmeshes = try! MTKMesh.newMeshes(asset: asset, device: lib.device).modelIOMeshes
		return mdlmeshes.map {Mesh($0, type: type)}
	}
	
	
	static func plane(seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			MDLMesh(
				planeWithExtent: v3f(1, 0, 1),
				segments: simd_uint2(seg, seg),
				geometryType: .triangles,
				allocator: Mesh.bufalloc
			),
			type: type
		)
	}
	static func box(seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			MDLMesh(
				boxWithExtent: v3f(1, 1, 1),
				segments: simd_uint3(seg, seg, seg),
				inwardNormals: false,
				geometryType: .triangles,
				allocator: Mesh.bufalloc
			),
			type: type
		)
	}
	static func sphere(seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			MDLMesh(
				sphereWithExtent: v3f(1, 1, 1),
				segments: simd_uint2(seg, seg),
				inwardNormals: false,
				geometryType: .triangles,
				allocator: Mesh.bufalloc
			),
			type: type
		)
	}
	
}
