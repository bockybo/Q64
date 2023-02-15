import MetalKit


extension MTKMesh {
	
	private static let alloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func load(path: String) -> [MTKMesh] {
		let url = util.url(path)!
		return try! MTKMesh.newMeshes(
			asset: MDLAsset(
				url: url,
				vertexDescriptor: lib.vtxdescr,
				bufferAllocator: MTKMesh.alloc
			),
			device: lib.device
		).metalKitMeshes
	}
	
	static func para(vtcs: [lib.vtx], idcs: [UInt16], type: MDLGeometryType = .triangles) -> MTKMesh {
		let vtxdata = Data(bytes: vtcs, count: vtcs.count * util.sizeof(lib.vtx.self))
		let idxdata = Data(bytes: idcs, count: idcs.count * util.sizeof(UInt16.self))
		let vtxbuf = MTKMesh.alloc.newBuffer(with: vtxdata, type: .vertex)
		let idxbuf = MTKMesh.alloc.newBuffer(with: idxdata, type: .index)
		let mesh = MDLMesh(
			vertexBuffer: vtxbuf,
			vertexCount: vtcs.count,
			descriptor: lib.vtxdescr,
			submeshes: [MDLSubmesh(
				indexBuffer: idxbuf,
				indexCount: idcs.count,
				indexType: .uInt16,
				geometryType: type,
				material: nil
			)]
		)
		return try! MTKMesh(mesh: mesh, device: lib.device)
	}
	
	static func box(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return try! MTKMesh(mesh: MDLMesh(
			boxWithExtent:		float3(1),
			segments:			uint3(seg, seg, seg),
			inwardNormals: 		invnml,
			geometryType:		type,
			allocator:			MTKMesh.alloc), device: lib.device)
	}
	static func sph(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return try! MTKMesh(mesh: MDLMesh(
			sphereWithExtent: 	float3(1),
			segments: 			uint2(seg, seg),
			inwardNormals:		invnml,
			geometryType: 		type,
			allocator:			MTKMesh.alloc), device: lib.device)
	}
	
}
