import MetalKit


struct Mesh: Renderable {
	let vtxprim: Vtxprim
	let idxprim: Idxprim
	
	init(_ mesh: MTKMesh, type: MTLPrimitiveType) {
		self.vtxprim = Vtxprim(bufs: mesh.vertexBuffers)
		self.idxprim = Idxprim(subs: mesh.submeshes, type: type)
	}
	
	func render(enc: MTLRenderCommandEncoder) {self.render(enc: enc, n: 1)}
	func render(enc: MTLRenderCommandEncoder, n: Int) {
		self.vtxprim.render(enc: enc)
		self.idxprim.render(enc: enc, n: n)
	}
	
	static let bufalloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func load(path: String, type: MTLPrimitiveType = .triangle) -> [Mesh] {
		let url = util.url(path)!
		let asset = MDLAsset(
			url: url,
			vertexDescriptor: lib.vdescr,
			bufferAllocator: Mesh.bufalloc
		)
		let mdlmeshes = try! MTKMesh.newMeshes(asset: asset, device: lib.device).modelIOMeshes
		return mdlmeshes.map {Mesh($0, type: type)}
	}
	
	init(_ mesh: MDLMesh, type: MTLPrimitiveType = .triangle) {
		mesh.vertexDescriptor = lib.vdescr
		mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)
		let mesh = try! MTKMesh(mesh: mesh, device: lib.device)
		self.init(mesh, type: type)
	}
	
	init(vtcs: [v3f], idcs: [UInt16], type: MTLPrimitiveType = .triangle) {
		
		let vtxbuf = Mesh.bufalloc.newBuffer(vtcs.count * util.sizeof(v3f.self), type: .vertex)
		let idxbuf = Mesh.bufalloc.newBuffer(idcs.count * util.sizeof(UInt16.self), type: .index)
		
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
			descriptor: lib.vdescr,
			submeshes: subs
		)
		
		self.init(mesh, type: type)
		
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
