import MetalKit


class lib {
	
	static let device = MTLCreateSystemDefaultDevice()!
	
	static let rstate_main = lib.rstate(vtx: "vtx_main", frg: "frg_main")
	static let rstate_text = lib.rstate(vtx: "vtx_main", frg: "frg_text")
	
	static let vdescr: MDLVertexDescriptor = {
		let descr = MDLVertexDescriptor()
		descr.attributes[0] = MDLVertexAttribute(
			name: MDLVertexAttributePosition,
			format: .float3,
			offset: 0,
			bufferIndex: 0
		)
		descr.attributes[1] = MDLVertexAttribute(
			name: MDLVertexAttributeNormal,
			format: .float3,
			offset: util.sizeof(f32.self) * 3,
			bufferIndex: 0
		)
		descr.attributes[2] = MDLVertexAttribute(
			name: MDLVertexAttributeTextureCoordinate,
			format: .float2,
			offset: util.sizeof(f32.self) * 5,
			bufferIndex: 0
		)
		descr.setPackedOffsets()
		descr.setPackedStrides()
		return descr
	}()
	
	static func rstate(vtx: String, frg: String) -> MTLRenderPipelineState {
		
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = lib.vdescr.mtl
		
		descr.colorAttachments[0].pixelFormat	= Config.color_fmt
		descr.depthAttachmentPixelFormat		= Config.depth_fmt
		
		descr.colorAttachments[0].isBlendingEnabled				= true
		descr.colorAttachments[0].rgbBlendOperation				= .add
		descr.colorAttachments[0].alphaBlendOperation			= .add
		descr.colorAttachments[0].sourceRGBBlendFactor			= .sourceAlpha
		descr.colorAttachments[0].sourceAlphaBlendFactor		= .sourceAlpha
		descr.colorAttachments[0].destinationRGBBlendFactor		= .oneMinusSourceAlpha
		descr.colorAttachments[0].destinationAlphaBlendFactor	= .oneMinusSourceAlpha
		
		let lib = lib.device.makeDefaultLibrary()!
		descr.vertexFunction	= lib.makeFunction(name: vtx)!
		descr.fragmentFunction	= lib.makeFunction(name: frg)!
		
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}
	
	static let dstate: MTLDepthStencilState = {
		let descr = MTLDepthStencilDescriptor()
		descr.isDepthWriteEnabled = true
		descr.depthCompareFunction = .less
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}()
	
	static let sstate: MTLSamplerState = {
		let descr = MTLSamplerDescriptor()
		descr.normalizedCoordinates = true
		descr.magFilter = .linear
		descr.minFilter = .linear
		descr.sAddressMode = .repeat
		descr.tAddressMode = .repeat
		return lib.device.makeSamplerState(descriptor: descr)!
	}()
	
}


extension MDLVertexDescriptor {
	var mtl: MTLVertexDescriptor {return MTKMetalVertexDescriptorFromModelIO(self)!}
}
extension MTLVertexDescriptor {
	var mdl: MDLVertexDescriptor {return MTKModelIOVertexDescriptorFromMetal(self)}
}
