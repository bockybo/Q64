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
	static let vtxshaders = [
		"main": lib.devlib.makeFunction(name: "vtx_main")!,
		"shdw": lib.devlib.makeFunction(name: "vtx_shdw")!,
		"quad": lib.devlib.makeFunction(name: "vtx_quad")!,
		"mask": lib.devlib.makeFunction(name: "vtx_mask")!,
		"lpos": lib.devlib.makeFunction(name: "vtx_lpos")!,
	]
	static let frgshaders = [
		"main": lib.devlib.makeFunction(name: "frg_main")!,
		"light": lib.devlib.makeFunction(name: "frg_light")!,
	]
	
	
	struct vtx {
		var pos: (float, float, float) = (0, 0, 0)
		var nml: (float, float, float) = (1, 0, 0)
		var tex: (float, float) = (0, 0)
	}
	
	static func mdlvtxdescr(_ attrs: [(fmt: MDLVertexFormat, name: String)]) -> MDLVertexDescriptor {
		let descr = MDLVertexDescriptor()
		for (i, (fmt, name)) in attrs.enumerated() {
			descr.attributes[i] = MDLVertexAttribute(name: name, format: fmt, offset: 0, bufferIndex: 0)
		}
		descr.setPackedOffsets()
		descr.setPackedStrides()
		return descr
	}
	
	static let mdlvtxdescrs = [
		"base": lib.mdlvtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
		]),
		"main": lib.mdlvtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
			(fmt: .float3, name: MDLVertexAttributeNormal),
			(fmt: .float2, name: MDLVertexAttributeTextureCoordinate),
		]),
	]
	static let mtkvtxdescrs = lib.mdlvtxdescrs.mapValues(MTKMetalVertexDescriptorFromModelIO)
	
	static func depthstate(
		cmp: MTLCompareFunction,
		wrt: Bool = false,
		stencilfront: MTLStencilDescriptor? = nil,
		stencilback:  MTLStencilDescriptor? = nil
	) -> MTLDepthStencilState {
		let descr = MTLDepthStencilDescriptor()
		descr.isDepthWriteEnabled = wrt
		descr.depthCompareFunction = cmp
		descr.frontFaceStencil = stencilfront
		descr.backFaceStencil = stencilback
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}
	static func stencildescr(
		faildepth:   MTLStencilOperation = .keep,
		failstencil: MTLStencilOperation = .keep,
		pass: MTLStencilOperation = .keep,
		cmp: MTLCompareFunction = .always
	) -> MTLStencilDescriptor {
		let descr = MTLStencilDescriptor()
		descr.depthFailureOperation = faildepth
		descr.stencilFailureOperation = failstencil
		descr.depthStencilPassOperation = pass
		descr.stencilCompareFunction = cmp
		return descr
	}
	
	static func pipestate(
		vtxdescr: MTLVertexDescriptor? = nil,
		vtxshader: MTLFunction? = nil,
		frgshader: MTLFunction? = nil,
		fmts: [Int : MTLPixelFormat] = [:]
	) -> MTLRenderPipelineState {
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = vtxdescr
		descr.vertexFunction = vtxshader
		descr.fragmentFunction = frgshader
		for (i, fmt) in fmts {
			switch i {
				case -2: descr.stencilAttachmentPixelFormat		= fmt;		break
				case -1: descr.depthAttachmentPixelFormat		= fmt;		break
				default: descr.colorAttachments[i].pixelFormat	= fmt
			}
		}
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}
	
	static func passdescr(fmts: [Int : MTLPixelFormat], size: uint2) -> MTLRenderPassDescriptor {
		let descr = MTLRenderPassDescriptor()
		for (i, fmt) in fmts {
			let att: MTLRenderPassAttachmentDescriptor
			switch i {
				case -2: att = descr.stencilAttachment; 	break
				case -1: att = descr.depthAttachment; 		break
				default: att = descr.colorAttachments[i]
			}
			att.loadAction = .clear
			att.storeAction = .store
			att.texture = lib.texture(
				fmt: fmt,
				size: size,
				storage: .private,
				usage: [.shaderRead, .renderTarget])
		}
		return descr
	}
	
	
	static func texture(
		fmt: MTLPixelFormat,
		size: uint2,
		storage: MTLStorageMode = .private,
		usage: MTLTextureUsage = .shaderRead
	) -> MTLTexture {
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: fmt,
			width:  Int(size.x),
			height: Int(size.y),
			mipmapped: false
		)
		descr.storageMode = storage
		descr.usage = usage
		return lib.device.makeTexture(descriptor: descr)!
	}
	static func texture(path: String) -> MTLTexture {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		return try! ldr.newTexture(URL: url, options: nil)
	}
	
	
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	static func mesh(
		_ mesh: MDLMesh,
		descr: MDLVertexDescriptor = lib.mdlvtxdescrs["main"]!,
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
		nml: Bool = false,
		tex: Bool = false
	) -> [MTKMesh] {
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		return try! MTKMesh.newMeshes(
			asset: MDLAsset(
				url: url,
				vertexDescriptor: lib.mdlvtxdescrs["main"]!,
				bufferAllocator: lib.meshalloc
			),
			device: lib.device
		).modelIOMeshes.map {mesh in lib.mesh(mesh, nml: nml, tex: tex)}
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
				descriptor: lib.mdlvtxdescrs["main"]!,
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
			allocator:			lib.meshalloc))
	}
	static func sphmesh(_ seg: uint, type: MDLGeometryType = .triangles, invnml: Bool = false) -> MTKMesh {
		return lib.mesh(MDLMesh(
			sphereWithExtent: 	float3(1),
			segments: 			uint2(seg, seg),
			inwardNormals:		invnml,
			geometryType: 		type,
			allocator:			lib.meshalloc))
	}
	
	class Buffer<T> {
		let buf: MTLBuffer
		var ptr: UnsafeMutablePointer<T>
		init(_ len: Int) {
			self.buf = lib.device.makeBuffer(
				length: len * sizeof(T.self),
				options: .storageModeShared)!
			self.ptr = self.buf.contents().assumingMemoryBound(to: T.self)
		}
		var count: Int {return self.buf.length / sizeof(T.self)}
		subscript(i: Int) -> T {
			get {return self.ptr[i]}
			set(value) {self.ptr[i] = value}
		}
	}
	
}
