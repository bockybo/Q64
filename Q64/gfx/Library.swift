import MetalKit


func sizeof<T>(_: T.Type) -> Int {return MemoryLayout<T>.stride}
func sizeof<T>(_: T) -> Int {return sizeof(T.self)}

class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	static let deflib = lib.device.makeDefaultLibrary()!
	
	
	static func shader(_ name: String) -> MTLFunction {return lib.deflib.makeFunction(name: name)!}
	static let vtxshaders = [
		"shade": 	lib.shader("vtx_shade"),
		"main": 	lib.shader("vtx_main"),
		"quad": 	lib.shader("vtx_quad"),
		"mask":		lib.shader("vtx_mask"),
		"light":	lib.shader("vtx_light"),
	]
	static let frgshaders = [
		"gbuf": 	lib.shader("frg_gbuf"),
		"quad":		lib.shader("frg_quad"),
		"icos":		lib.shader("frg_icos"),
		"cone":		lib.shader("frg_cone"),
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
			(fmt: .float4, name: MDLVertexAttributeTangent),
			(fmt: .float2, name: MDLVertexAttributeTextureCoordinate)
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
	static func passdescr(_ setup: (MTLRenderPassDescriptor)->()) -> MTLRenderPassDescriptor {
		let descr = MTLRenderPassDescriptor()
		setup(descr)
		return descr
	}
	
	
	static func buffer(_ len: Int, label: String? = nil) -> MTLBuffer {
		let buf = lib.device.makeBuffer(length: len, options: .storageModeShared)!
		buf.label = label
		return buf
	}
	
	
	class tex {
		private static let loader = MTKTextureLoader(device: lib.device)
		
		static func load(
			_ path: String,
			srgb: Bool = false,
			label: String? = nil,
			usage: MTLTextureUsage = .shaderRead,
			storage: MTLStorageMode = .private
		) -> MTLTexture {
			let url = Bundle.main.url(forResource: path, withExtension: nil)!
			let tex = try! lib.tex.loader.newTexture(URL: url, options: [
				.SRGB : srgb,
				.textureStorageMode : storage.rawValue,
				.textureUsage : usage.rawValue
			])
			tex.label = label
			return tex
		}
		
		static func base(
			fmt: MTLPixelFormat,
			res: uint2,
			label: String? = nil,
			usage: MTLTextureUsage = .shaderRead,
			storage: MTLStorageMode = .private,
			nslices: Int? = nil
		) -> MTLTexture {
			let descr = MTLTextureDescriptor()
			if let nslices = nslices {
				descr.textureType = .type2DArray
				descr.arrayLength = nslices
			} else {
				descr.textureType = .type2D
			}
			descr.pixelFormat = fmt
			descr.width  = Int(res.x)
			descr.height = Int(res.y)
			descr.usage = usage
			descr.storageMode = storage
			let tex = lib.device.makeTexture(descriptor: descr)!
			tex.label = label
			return tex
		}
		
	}
	
	
	class mesh {
		static let alloc = MTKMeshBufferAllocator(device: lib.device)
		
		static func base(
			_ mesh: MDLMesh,
			descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!,
			ctm: float4x4? = nil
		) -> MTKMesh {
			
			if let ctm = ctm {
				let attr = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition)!
				assert(attr.format == .float3)
				for i in 0..<mesh.vertexCount {
					let raw = attr.dataStart + i*attr.stride
					let ptr = raw.assumingMemoryBound(to: float3.self)
					ptr.pointee = (ctm * float4(ptr.pointee, 1)).xyz
				}
			}
			
			let names = descr.attributes.map {attr in (attr as! MDLVertexAttribute).name}
			let needs: (String) -> Bool = {name in
				return names.contains(name) && mesh.vertexAttributeData(forAttributeNamed: name) == nil
			}
			if needs(MDLVertexAttributeNormal) {mesh.addNormals(
				withAttributeNamed: MDLVertexAttributeNormal,
				creaseThreshold: 0.5
			)}
			if needs(MDLVertexAttributeTextureCoordinate) {mesh.addUnwrappedTextureCoordinates(
				forAttributeNamed: MDLVertexAttributeTextureCoordinate
			)}
			if needs(MDLVertexAttributeTangent) {mesh.addOrthTanBasis(
				forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
				normalAttributeNamed: MDLVertexAttributeNormal,
				tangentAttributeNamed: MDLVertexAttributeTangent
			)}
			
			mesh.vertexDescriptor = descr
			return try! MTKMesh(mesh: mesh, device: lib.device)
			
		}
		
		static func load(
			_ path: String,
			descr: MDLVertexDescriptor = lib.vtxdescrs["main"]!,
			ctm: float4x4? = nil
		) -> [MTKMesh] {
			let url = Bundle.main.url(forResource: path, withExtension: nil)!
			let asset = MDLAsset(
				url: url,
				vertexDescriptor: nil,
				bufferAllocator: lib.mesh.alloc
			)
			let meshes = try! MTKMesh.newMeshes(asset: asset, device: lib.device).modelIOMeshes
			return meshes.map {lib.mesh.base($0, descr: descr, ctm: ctm)}
		}
		
		
		static func quad(
			dim: float3					= float3(1),
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			planeWithExtent: 			dim,
			segments: 					uint2(1),
			geometryType: 				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func icos(
			dim: float3					= float3(1),
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			icosahedronWithExtent: 		dim,
			inwardNormals: 				inwd,
			geometryType: 				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func box(
			dim: float3					= float3(1),
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			boxWithExtent:	 			dim,
			segments: 					uint3(1),
			inwardNormals: 				inwd,
			geometryType: 				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func sph(
			dim: float3					= float3(1),
			seg: uint2					= uint2(1),
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			sphereWithExtent:			dim,
			segments:					seg,
			inwardNormals:				inwd,
			geometryType:				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func hem(
			dim: float3					= float3(1),
			seg: uint2					= uint2(1),
			cap: Bool					= true,
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			hemisphereWithExtent:		dim,
			segments:					seg,
			inwardNormals:				inwd,
			cap:						cap,
			geometryType:				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func cyl(
			dim: float3					= float3(1),
			seg: uint2					= uint2(1),
			top: Bool					= true,
			bot: Bool					= true,
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			cylinderWithExtent:			dim,
			segments:					seg,
			inwardNormals: 				inwd,
			topCap: 					top,
			bottomCap:					bot,
			geometryType:				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func cone(
			dim: float3					= float3(1),
			seg: uint2					= uint2(1),
			cap: Bool					= true,
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			coneWithExtent: 			dim,
			segments:					seg,
			inwardNormals: 				inwd,
			cap:						cap,
			geometryType: 				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		static func caps(
			dim: float3					= float3(1),
			seg: uint3					= uint3(1),
			cap: Bool					= true,
			inwd: Bool 					= false,
			prim: MDLGeometryType		= .triangles,
			ctm: float4x4?				= nil,
			descr: MDLVertexDescriptor	= lib.vtxdescrs["main"]!
		) -> MTKMesh {return lib.mesh.base(MDLMesh(
			capsuleWithExtent:			dim,
			cylinderSegments:			uint2(seg.x, seg.y),
			hemisphereSegments:			Int32(seg.z),
			inwardNormals:				inwd,
			geometryType:				prim,
			allocator: lib.mesh.alloc), descr: descr, ctm: ctm)
		}
		
	}
	
}
