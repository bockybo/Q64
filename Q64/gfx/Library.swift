import MetalKit

func sizeof<T>(_: T.Type) -> Int {
	return MemoryLayout<T>.stride
}
func sizeof<T>(_: T) -> Int {
	return sizeof(T.self)
}

class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	
	
	static let devlib = lib.device.makeDefaultLibrary()!
	static func shader(_ name: String) -> MTLFunction {return lib.devlib.makeFunction(name: name)!}
	static let vtxshaders = [
		"shade": 	lib.shader("vtx_shade"),
		"gbuf": 	lib.shader("vtx_gbuf"),
		"quad": 	lib.shader("vtx_quad"),
		"icos": 	lib.shader("vtx_icos"),
		"mask":		lib.shader("vtx_mask"),
	]
	static let frgshaders = [
		"gbuf": 	lib.shader("frg_gbuf"),
		"light": 	lib.shader("frg_light"),
	]
	
	
	static func pipestate(_ setup: (MTLRenderPipelineDescriptor)->()) -> MTLRenderPipelineState {
		let descr = MTLRenderPipelineDescriptor()
		setup(descr)
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}
	static func depthstate(_ setup: (MTLDepthStencilDescriptor, MTLStencilDescriptor)->()) -> MTLDepthStencilState {
		let descr = MTLDepthStencilDescriptor()
		let op = MTLStencilDescriptor()
		setup(descr, op)
		descr.frontFaceStencil = op
		descr.backFaceStencil = op
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}
	
	
	static func texture(
		fmt: MTLPixelFormat,
		size: uint2,
		storage: MTLStorageMode = .private,
		usage: MTLTextureUsage = .shaderRead,
		label: String? = nil
	) -> MTLTexture {
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: fmt,
			width:  Int(size.x),
			height: Int(size.y),
			mipmapped: false
		)
		descr.storageMode = storage
		descr.usage = usage
		let tex = lib.device.makeTexture(descriptor: descr)!
		tex.label = label
		return tex
	}
	static func texture(path: String) -> MTLTexture {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		return try! ldr.newTexture(URL: url, options: nil)
	}
	
	
	
	struct vtx {
		var pos: (float, float, float) = (0, 0, 0)
		var nml: (float, float, float) = (1, 0, 0)
		var tex: (float, float) = (0, 0)
	}
	
	static func vtxdescr(_ attrs: [(fmt: MDLVertexFormat, name: String)]) -> MDLVertexDescriptor {
		let descr = MDLVertexDescriptor()
		for (i, (fmt, name)) in attrs.enumerated() {
			descr.attributes[i] = MDLVertexAttribute(name: name, format: fmt, offset: 0, bufferIndex: 0)
		}
		descr.setPackedOffsets()
		descr.setPackedStrides()
		return descr
	}
	static let vtxdescrs = [
		"base": lib.vtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
		]),
		"main": lib.vtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
			(fmt: .float3, name: MDLVertexAttributeNormal),
			(fmt: .float2, name: MDLVertexAttributeTextureCoordinate),
		]),
	]
	
	
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func mesh(
		_ mesh: MDLMesh,
		descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!,
		nml: Bool = false,
		tex: Bool = false
	) -> MTKMesh {
		mesh.vertexDescriptor = descr
		if nml {mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0)}
		if tex {mesh.addUnwrappedTextureCoordinates(forAttributeNamed: MDLVertexAttributeTextureCoordinate)}
		return try! MTKMesh(mesh: mesh, device: lib.device)
	}
	static func meshes(
		path: String,
		descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!,
		nml: Bool = false,
		tex: Bool = false
	) -> [MTKMesh] {
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		return try! MTKMesh.newMeshes(
			asset: MDLAsset(
				url: url,
				vertexDescriptor: nil,
				bufferAllocator: lib.meshalloc
			),
			device: lib.device
		).modelIOMeshes.map {mesh in lib.mesh(mesh, descr: descr, nml: nml, tex: tex)}
	}
	
	static func mesh(
		vtcs: [lib.vtx],
		idcs: [uint],
		type: MDLGeometryType = .triangles,
		nml: Bool = false,
		tex: Bool = false
	) -> MTKMesh {
		let vtxdata = Data(bytes: vtcs, count: vtcs.count * sizeof(lib.vtx.self))
		let idxdata = Data(bytes: idcs, count: idcs.count * sizeof(uint.self))
		let vtxbuf = lib.meshalloc.newBuffer(with: vtxdata, type: .vertex)
		let idxbuf = lib.meshalloc.newBuffer(with: idxdata, type: .index)
		return lib.mesh(MDLMesh(
			vertexBuffer: vtxbuf,
				vertexCount: vtcs.count,
				descriptor: lib.vtxdescrs["main"]!,
				submeshes: [MDLSubmesh(
					indexBuffer: idxbuf,
					indexCount: idcs.count,
					indexType: .uInt32,
					geometryType: type,
					material: nil
				)]
			),
			nml: nml,
			tex: tex
		)
	}
	static func mesh(
		vtcs: [float3],
		idcs: [uint],
		type: MDLGeometryType = .triangles
	) -> MTKMesh {
		return lib.mesh(
			vtcs: vtcs.map {pos in lib.vtx(pos: (pos.x, pos.y, pos.z))},
			idcs: idcs,
			type: type,
			nml: true,
			tex: true
		)
	}
	
	static func boxmesh(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return lib.mesh(MDLMesh(
			boxWithExtent:		float3(1),
			segments:			uint3(seg, seg, seg),
			inwardNormals: 		invnml,
			geometryType:		type,
			allocator:			lib.meshalloc), descr: lib.vtxdescrs["main"]!)
	}
	static func sphmesh(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return lib.mesh(MDLMesh(
			sphereWithExtent: 	float3(1),
			segments: 			uint2(seg, seg),
			inwardNormals:		invnml,
			geometryType: 		type,
			allocator:			lib.meshalloc), descr: lib.vtxdescrs["main"]!)
	}
	
	static let quadmesh = lib.mesh(MDLMesh(
			planeWithExtent: float3(2, 2, 0),
			segments: uint2(1, 1),
			geometryType: .triangles,
			allocator: lib.meshalloc), descr: lib.vtxdescrs["base"]!
	)
	static let icosmesh = lib.mesh(MDLMesh(
			icosahedronWithExtent: float3(12 / (sqrtf(3) * (3 + sqrtf(5)))),
			inwardNormals: false,
			geometryType: .triangles,
			allocator: lib.meshalloc), descr: lib.vtxdescrs["base"]!
	)
	
	
	class Buffer<T> {
		let buf: MTLBuffer
		init(_ count: Int) {
			self.buf = lib.device.makeBuffer(
				length: count * sizeof(T.self),
				options: .storageModeShared)!
		}
		var count: Int {return self.buf.length / sizeof(T.self)}
		var ptr: UnsafeMutableBufferPointer<T> {
			let start = self.buf.contents().assumingMemoryBound(to: T.self)
			return .init(start: start, count: self.count)
		}
		subscript(i: Int) -> T {
			get {return self.ptr[i]}
			set(value) {self.ptr[i] = value}
		}
	}
	
}
