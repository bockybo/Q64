import MetalKit


func sizeof<T>(_: T.Type) -> Int {return MemoryLayout<T>.stride}
func sizeof<T>(_: T) -> Int {return sizeof(T.self)}

class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	static let deflib = lib.device.makeDefaultLibrary()!
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	static let textureloader = MTKTextureLoader(device: lib.device)
	
	
	static func shader(_ name: String) -> MTLFunction {return lib.deflib.makeFunction(name: name)!}
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
			(fmt: .float4, name: MDLVertexAttributeTangent)
		]),
	]
	
	
	static func pipestate(_ setup: (MTLRenderPipelineDescriptor)->()) -> MTLRenderPipelineState {
		let descr = MTLRenderPipelineDescriptor()
		setup(descr)
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}
	static func depthstate(_ setup: (MTLDepthStencilDescriptor)->()) -> MTLDepthStencilState {
		let descr = MTLDepthStencilDescriptor()
		setup(descr)
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}
	
	
	static func texture(
		path: String,
		srgb: Bool = false,
		storage: MTLStorageMode = .private,
		usage: MTLTextureUsage = .shaderRead
	) -> MTLTexture {
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		return try! lib.textureloader.newTexture(URL: url, options: [
			.SRGB : false,
			.textureStorageMode : storage.rawValue,
			.textureUsage : usage.rawValue
		])
	}
	
	static func texture(
		fmt: MTLPixelFormat,
		res: uint2,
		storage: MTLStorageMode = .private,
		usage: MTLTextureUsage = .shaderRead,
		label: String? = nil
	) -> MTLTexture {
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: fmt,
			width:  Int(res.x),
			height: Int(res.y),
			mipmapped: false
		)
		descr.storageMode = storage
		descr.usage = usage
		let tex = lib.device.makeTexture(descriptor: descr)!
		tex.label = label
		return tex
	}
	
	static func texture<T>(
		src: T,
		fmt: MTLPixelFormat,
		usage: MTLTextureUsage = .shaderRead,
		label: String? = nil
	) -> MTLTexture {
		let tex = lib.texture(fmt: fmt, res: uint2(1), storage: .shared, usage: usage, label: label)
		var src = src
		tex.replace(
			region: .init(
				origin: .init(x: 0, y: 0, z: 0),
				size: .init(width: 1, height: 1, depth: 1)),
			mipmapLevel: 0,
			withBytes: &src,
			bytesPerRow: sizeof(T.self)
		)
		return tex
	}
	
	
	static func mesh(_ mesh: MDLMesh, descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!) -> MTKMesh {
		mesh.setVertexDescriptor(descr)
		return try! MTKMesh(mesh: mesh, device: lib.device)
	}
	
	static func meshes(path: String, descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!) -> [MTKMesh] {
		let url = Bundle.main.url(forResource: path, withExtension: nil)!
		let asset = MDLAsset(
			url: url,
			vertexDescriptor: nil,
			bufferAllocator: lib.meshalloc
		)
		let mdls = try! MTKMesh.newMeshes(asset: asset, device: lib.device).modelIOMeshes
		let mtks = mdls.map {mesh in lib.mesh(mesh, descr: descr)}
		return mtks
	}
	
	
	class Buffer<T> {
		let buf: MTLBuffer
		let ptr: UnsafeMutableBufferPointer<T>
		init(_ count: Int) {
			self.buf = lib.device.makeBuffer(
				length: count * sizeof(T.self),
				options: .storageModeManaged)!
			let raw = self.buf.contents()
			let ptr = raw.assumingMemoryBound(to: T.self)
			self.ptr = .init(start: ptr, count: count)
		}
		var count: Int {return self.ptr.count}
		subscript(i: Int) -> T {
			get {return self.ptr[i]}
			set(value) {
				self.ptr[i] = value
				let lower = sizeof(T.self) * i
				let upper = sizeof(T.self) * (i + 1)
				self.buf.didModifyRange(lower..<upper)
			}
		}
	}
	
}


class meshlib {
	
	class func quad(
		dim: float3					= float3(1),
		seg: uint2	 				= uint2(1),
		descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles
	) -> MTKMesh {return lib.mesh(MDLMesh(
		planeWithExtent: 	dim,
		segments: 			seg,
		geometryType: 		prim,
		allocator: lib.meshalloc), descr: descr)
	}
	class func box(
		dim: float3					= float3(1),
		seg: uint3					= uint3(1),
		descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newBox(
		withDimensions: 	dim,
		segments: 			seg,
		geometryType: 		prim,
		inwardNormals: 		inwd,
		allocator: lib.meshalloc), descr: descr)
	}
	class func sph(
		dim: float3					= float3(1),
		seg: uint2					= uint2(1),
		descr: MDLVertexDescriptor 	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false,
		hemi: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newEllipsoid(
		withRadii:		 	dim,
		radialSegments:		Int(seg.x),
		verticalSegments: 	Int(seg.y),
		geometryType: 		prim,
		inwardNormals: 		inwd,
		hemisphere: 		hemi,
		allocator: lib.meshalloc), descr: descr)
	}
	class func icos(
		dim: float					= float(1),
		descr: MDLVertexDescriptor 	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newIcosahedron(
		withRadius: 		dim,
		inwardNormals: 		inwd,
		geometryType: 		prim,
		allocator: lib.meshalloc), descr: descr)
	}
	class func cyl(
		dim: float3					= float3(1),
		seg: uint2					= uint2(1),
		descr: MDLVertexDescriptor 	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newCylinder(
		withHeight: 		dim.y,
		radii:				float2(dim.x, dim.z),
		radialSegments:		Int(seg.x),
		verticalSegments: 	Int(seg.y),
		geometryType: 		prim,
		inwardNormals: 		inwd,
		allocator: lib.meshalloc), descr: descr)
	}
	class func cone(
		dim: float3					= float3(1),
		seg: uint2					= uint2(1),
		descr: MDLVertexDescriptor 	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newEllipticalCone(
		withHeight: 		dim.y,
		radii:				float2(dim.x, dim.z),
		radialSegments:		Int(seg.x),
		verticalSegments: 	Int(seg.y),
		geometryType: 		prim,
		inwardNormals: 		inwd,
		allocator: lib.meshalloc), descr: descr)
	}
	class func caps(
		dim: float3					= float3(1),
		seg: uint3					= uint3(1),
		descr: MDLVertexDescriptor 	= lib.vtxdescrs["main"]!,
		prim: MDLGeometryType		= .triangles,
		inwd: Bool = false
	) -> MTKMesh {return lib.mesh(MDLMesh.newCapsule(
		withHeight: 		dim.y,
		radii:				float2(dim.x, dim.z),
		radialSegments:		Int(seg.x),
		verticalSegments: 	Int(seg.y),
		hemisphereSegments:	Int(seg.z),
		geometryType: 		prim,
		inwardNormals: 		inwd,
		allocator: lib.meshalloc), descr: descr)
	}
	
}
