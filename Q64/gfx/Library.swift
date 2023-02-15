import MetalKit


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
			offset: 0 * util.sizeof(float.self),
			bufferIndex: 0
		)
		descr.attributes[1] = MDLVertexAttribute(
			name: MDLVertexAttributeNormal,
			format: .float3,
			offset: 3 * util.sizeof(float.self),
			bufferIndex: 0
		)
		descr.attributes[2] = MDLVertexAttribute(
			name: MDLVertexAttributeTextureCoordinate,
			format: .float2,
			offset: 5 * util.sizeof(float.self),
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
	
	static let lightpipestate = lib.pipestate("vtx_light", frgfn: "frg_main")
	static let shadepipestate = lib.pipestate("vtx_shade", color: false)
	
	static func shadepassdescr(_ tex: MTLTexture) -> MTLRenderPassDescriptor {
		let descr = MTLRenderPassDescriptor()
		descr.depthAttachment.loadAction = .clear
		descr.depthAttachment.storeAction = .store
		descr.depthAttachment.texture = tex
		return descr
	}
	
	static func texture(path: String) -> MTLTexture {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = util.url(path)!
		let tex = try! ldr.newTexture(URL: url, options: nil)
		return tex
	}
	static var white1x1: MTLTexture = {
		
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: cfg.color_fmt,
			width:  1,
			height: 1,
			mipmapped: false
		)
		descr.storageMode = .managed
		descr.usage = .shaderRead
		let tex = lib.device.makeTexture(descriptor: descr)!
		
		var hue = simd_uchar4(255, 255, 255, 255)
		let ogn = MTLOrigin(x: 0, y: 0, z: 0)
		let dim = MTLSize(width: 1, height: 1, depth: 1)
		let rgn = MTLRegion(origin: ogn, size: dim)
		tex.replace(region: rgn, mipmapLevel: 0, withBytes: &hue, bytesPerRow: util.sizeof(hue))
		
		return tex
		
	}()
	
}
