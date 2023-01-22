import MetalKit


class lib {
	
	static let vtxdescr: MDLVertexDescriptor = {
		let descr = MDLVertexDescriptor()
		descr.attributes[0] = MDLVertexAttribute(
			name: MDLVertexAttributePosition,
			format: .float3,
			offset: util.sizeof(v3f.self),
			bufferIndex: 0
		)
		descr.attributes[1] = MDLVertexAttribute(
			name: MDLVertexAttributeNormal,
			format: .float3,
			offset: util.sizeof(v3f.self) * 2,
			bufferIndex: 0
		)
		descr.setPackedOffsets()
		descr.setPackedStrides()
		return descr
	}()
	
	static let rdescr: MTLRenderPipelineDescriptor = {
		
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = lib.vtxdescr.mtl
		
		descr.colorAttachments[0].pixelFormat	= Config.color_fmt
		descr.depthAttachmentPixelFormat		= Config.depth_fmt
		
		descr.colorAttachments[0].isBlendingEnabled				= true
		descr.colorAttachments[0].rgbBlendOperation				= .add
		descr.colorAttachments[0].alphaBlendOperation			= .add
		descr.colorAttachments[0].sourceRGBBlendFactor			= .sourceAlpha
		descr.colorAttachments[0].sourceAlphaBlendFactor		= .sourceAlpha
		descr.colorAttachments[0].destinationRGBBlendFactor		= .oneMinusSourceAlpha
		descr.colorAttachments[0].destinationAlphaBlendFactor	= .oneMinusSourceAlpha
		
		return descr
		
	}()
	
	static func dstate(_ device: MTLDevice) -> MTLDepthStencilState {
		let descr = MTLDepthStencilDescriptor()
		descr.isDepthWriteEnabled = true
		descr.depthCompareFunction = .less
		return device.makeDepthStencilState(descriptor: descr)!
	}
	
	static func rstate(_ device: MTLDevice, vtx: String, frg: String) -> MTLRenderPipelineState {
		let descr = lib.rdescr
		let lib = device.makeDefaultLibrary()!
		descr.vertexFunction	= lib.makeFunction(name: vtx)!
		descr.fragmentFunction	= lib.makeFunction(name: frg)!
		return try! device.makeRenderPipelineState(descriptor: descr)
	}
	
	static func rstate_main(_ device: MTLDevice) -> MTLRenderPipelineState {return lib.rstate(device, vtx: "vtx_main", frg: "frg_main")}
	static func rstate_inst(_ device: MTLDevice) -> MTLRenderPipelineState {return lib.rstate(device, vtx: "vtx_inst", frg: "frg_main")}
	
}


extension MDLVertexDescriptor {
	var mtl: MTLVertexDescriptor {return MTKMetalVertexDescriptorFromModelIO(self)!}
}
extension MTLVertexDescriptor {
	var mdl: MDLVertexDescriptor {return MTKModelIOVertexDescriptorFromMetal(self)}
}
