import MetalKit

func sizeof<T>(_: T.Type) -> Int {
	return MemoryLayout<T>.stride
}
func sizeof<T>(_: T) -> Int {
	return sizeof(T.self)
}

class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	
	struct vtx {
		var pos: (float, float, float) = (0, 0, 0)
		var nml: (float, float, float) = (1, 0, 0)
		var tex: (float, float) = (0, 0)
	}
	static let vtxdescr: MDLVertexDescriptor = {
		let descr = MDLVertexDescriptor()
		descr.attributes[0] = MDLVertexAttribute(
			name: MDLVertexAttributePosition,
			format: .float3,
			offset: 0 * sizeof(float.self),
			bufferIndex: 0
		)
		descr.attributes[1] = MDLVertexAttribute(
			name: MDLVertexAttributeNormal,
			format: .float3,
			offset: 3 * sizeof(float.self),
			bufferIndex: 0
		)
		descr.attributes[2] = MDLVertexAttribute(
			name: MDLVertexAttributeTextureCoordinate,
			format: .float2,
			offset: 5 * sizeof(float.self),
			bufferIndex: 0
		)
		descr.setPackedOffsets()
		descr.setPackedStrides()
		return descr
	}()
	
	static let depthstate: MTLDepthStencilState = {
		let descr = MTLDepthStencilDescriptor()
		descr.isDepthWriteEnabled = true
		descr.depthCompareFunction = .less
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}()
	
	static func pipestate(
		_ vtxfn: String,
		frgfn: String? = nil,
		color: Bool = true,
		depth: Bool = true
	) -> MTLRenderPipelineState {
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(lib.vtxdescr)!
		if color {descr.colorAttachments[0].pixelFormat	= cfg.color_fmt}
		if depth {descr.depthAttachmentPixelFormat		= cfg.depth_fmt}
		let devlib = lib.device.makeDefaultLibrary()!
		descr.vertexFunction = devlib.makeFunction(name: vtxfn)!
		if let frgfn = frgfn {descr.fragmentFunction = devlib.makeFunction(name: frgfn)!}
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}
	
	static func passdescr(_ textures: [Int : MTLTexture]) -> MTLRenderPassDescriptor {
		let descr = MTLRenderPassDescriptor()
		for (i, tex) in textures {
			if i == -1 {
				descr.depthAttachment.texture = tex
				descr.depthAttachment.loadAction = .clear
				descr.depthAttachment.storeAction = .store
			} else {
				descr.colorAttachments[i].texture = tex
				descr.colorAttachments[i].loadAction = .clear
				descr.colorAttachments[i].storeAction = .store
			}
		}
		return descr
	}
	
	
	static func url(_ path: String?, ext: String? = nil) -> URL? {
		return Bundle.main.url(forResource: path, withExtension: ext)
	}
	
	static func texture(path: String) -> MTLTexture {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = lib.url(path)!
		return try! ldr.newTexture(URL: url, options: nil)
	}
	static func texture(
		dim: uint2,
		fmt: MTLPixelFormat,
		storage: MTLStorageMode = .private,
		usage: MTLTextureUsage = .shaderRead
	) -> MTLTexture {
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: fmt,
			width:  Int(dim.x),
			height: Int(dim.y),
			mipmapped: false
		)
		descr.storageMode = storage
		descr.usage = usage
		return lib.device.makeTexture(descriptor: descr)!
	}
	static var white1x1: MTLTexture = {
		let tex = lib.texture(dim: uint2(1, 1), fmt: cfg.color_fmt, storage: .managed)
		var hue = simd_uchar4(255, 255, 255, 255)
		let ogn = MTLOrigin(x: 0, y: 0, z: 0)
		let dim = MTLSize(width: 1, height: 1, depth: 1)
		let rgn = MTLRegion(origin: ogn, size: dim)
		tex.replace(region: rgn, mipmapLevel: 0, withBytes: &hue, bytesPerRow: sizeof(hue))
		return tex
	}()
	
	
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func mesh(path: String) -> [MTKMesh] {
		let url = lib.url(path)!
		return try! MTKMesh.newMeshes(
			asset: MDLAsset(
				url: url,
				vertexDescriptor: lib.vtxdescr,
				bufferAllocator: lib.meshalloc
			),
			device: lib.device
		).metalKitMeshes
	}
	
	static func mesh(
		vtcs: [lib.vtx],
		idcs: [UInt16],
		type: MDLGeometryType = .triangles,
		nml: Bool = false,
		tex: Bool = false
	) -> MTKMesh {
		let vtxdata = Data(bytes: vtcs, count: vtcs.count * sizeof(lib.vtx.self))
		let idxdata = Data(bytes: idcs, count: idcs.count * sizeof(UInt16.self))
		let vtxbuf = lib.meshalloc.newBuffer(with: vtxdata, type: .vertex)
		let idxbuf = lib.meshalloc.newBuffer(with: idxdata, type: .index)
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
		if nml {mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)}
		if tex {mesh.addUnwrappedTextureCoordinates(forAttributeNamed: MDLVertexAttributeTextureCoordinate)}
		return try! MTKMesh(mesh: mesh, device: lib.device)
	}
	static func mesh(
		vtcs: [float3],
		idcs: [UInt16],
		type: MDLGeometryType = .triangles
	) -> MTKMesh {
		let vtcs = vtcs.map {pos in lib.vtx(pos: (pos.x, pos.y, pos.z))}
		let mesh = lib.mesh(vtcs: vtcs, idcs: idcs, type: type, nml: true, tex: true)
		return mesh
	}
	
	static func boxmesh(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return try! MTKMesh(mesh: MDLMesh(
			boxWithExtent:		float3(1),
			segments:			uint3(seg, seg, seg),
			inwardNormals: 		invnml,
			geometryType:		type,
			allocator:			lib.meshalloc), device: lib.device)
	}
	static func sphmesh(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return try! MTKMesh(mesh: MDLMesh(
			sphereWithExtent: 	float3(1),
			segments: 			uint2(seg, seg),
			inwardNormals:		invnml,
			geometryType: 		type,
			allocator:			lib.meshalloc), device: lib.device)
	}
	
}
