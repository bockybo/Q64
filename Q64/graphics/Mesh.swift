import MetalKit


class Mesh: Renderable {
	let vtxprim: Vtxprim
	let idxprim: Idxprim
	
	init(mesh: MTKMesh, type: MTLPrimitiveType) {
		self.vtxprim = Vtxprim(bufs: mesh.vertexBuffers)
		self.idxprim = Idxprim(subs: mesh.submeshes, type: type)
	}
	
	func render(enc: MTLRenderCommandEncoder) {self.render(enc: enc, n: 1)}
	func render(enc: MTLRenderCommandEncoder, n: Int) {
		self.vtxprim.render(enc: enc)
		self.idxprim.render(enc: enc, n: n)
	}
	
	
	class func load(_ device: MTLDevice, path: String, type: MTLPrimitiveType = .triangle) -> [Mesh] {
		let url = Bundle.main.url(forResource: path, withExtension: "obj")!
		let asset = MDLAsset(
			url: url,
			vertexDescriptor: Renderer.mdldescr,
			bufferAllocator: MTKMeshBufferAllocator(device: device)
		)
		let mdlmeshes = try! MTKMesh.newMeshes(asset: asset, device: device).modelIOMeshes
		return mdlmeshes.map {Mesh(device, mesh: $0, type: type)}
	}
	
	convenience init(_ device: MTLDevice, mesh: MDLMesh, type: MTLPrimitiveType = .triangle) {
		mesh.vertexDescriptor = Renderer.mdldescr
		mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)
		let mesh = try! MTKMesh(mesh: mesh, device: device)
		self.init(
			mesh: mesh,
			type: type
		)
	}
	
	convenience init(_ device: MTLDevice, vtcs: [v3f], idcs: [UInt16], type: MTLPrimitiveType = .triangle) {
		
		let alloc = MTKMeshBufferAllocator(device: device)
		let vtxbuf = alloc.newBuffer(vtcs.count * util.sizeof(v3f.self), type: .vertex)
		let idxbuf = alloc.newBuffer(idcs.count * util.sizeof(UInt16.self), type: .index)
		
		let vtxptr = vtxbuf.map().bytes.assumingMemoryBound(to: v3f.self)
		let idxptr = idxbuf.map().bytes.assumingMemoryBound(to: UInt16.self)
		vtxptr.assign(from: vtcs, count: vtcs.count)
		idxptr.assign(from: idcs, count: idcs.count)
		
		let subs = [MDLSubmesh(
			indexBuffer: idxbuf,
			indexCount: idcs.count,
			indexType: .uInt16,
			geometryType: .triangles,
			material: nil
		)]
		let mesh = MDLMesh(
			vertexBuffer: vtxbuf,
			vertexCount: vtcs.count,
			descriptor: Renderer.mdldescr,
			submeshes: subs
		)
		
		self.init(
			device,
			mesh: mesh,
			type: type
		)
		
	}
	
	
	class func plane(_ device: MTLDevice, seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			device,
			mesh: MDLMesh(
				planeWithExtent: v3f(1, 0, 1),
				segments: simd_uint2(seg, seg),
				geometryType: .triangles,
				allocator: MTKMeshBufferAllocator(device: device)
			),
			type: type
		)
	}
	class func box(_ device: MTLDevice, seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			device,
			mesh: MDLMesh(
				boxWithExtent: v3f(1, 1, 1),
				segments: simd_uint3(seg, seg, seg),
				inwardNormals: false,
				geometryType: .triangles,
				allocator: MTKMeshBufferAllocator(device: device)
			),
			type: type
		)
	}
	class func sphere(_ device: MTLDevice, seg: UInt32, type: MTLPrimitiveType = .triangle) -> Mesh {
		return Mesh(
			device,
			mesh: MDLMesh(
				sphereWithExtent: v3f(1, 1, 1),
				segments: simd_uint2(seg, seg),
				inwardNormals: false,
				geometryType: .triangles,
				allocator: MTKMeshBufferAllocator(device: device)
			),
			type: type
		)
	}
	
}
