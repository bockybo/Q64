import MetalKit


class lib {
	
	static let device = MTLCreateSystemDefaultDevice()!
	
	static let fns = lib.device.makeDefaultLibrary()!
	static subscript(name: String) -> MTLFunction {return lib.fns.makeFunction(name: name)!}
	
	static let vtxdescr: MDLVertexDescriptor = {
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
	
	static let depthstate: MTLDepthStencilState = {
		let descr = MTLDepthStencilDescriptor()
		descr.isDepthWriteEnabled = true
		descr.depthCompareFunction = .less
		return lib.device.makeDepthStencilState(descriptor: descr)!
	}()
	
	static let lightpipestate: MTLRenderPipelineState = {
		
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
		
		descr.vertexFunction		= lib["vtx_light"]
		descr.fragmentFunction		= lib["frg_main"]
		
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}()
	
	static let shadepipestate: MTLRenderPipelineState = {
		
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = lib.vtxdescr.mtl
		
		descr.depthAttachmentPixelFormat = Config.depth_fmt
		
		descr.vertexFunction = lib["vtx_shade"]
		
		return try! lib.device.makeRenderPipelineState(descriptor: descr)
	}()
	
	static let shadepassdescr: MTLRenderPassDescriptor = {
		
		let descr = MTLRenderPassDescriptor()
		
		descr.depthAttachment.loadAction = .clear
		descr.depthAttachment.storeAction = .store
		descr.depthAttachment.clearDepth = 1.0
		
		return descr
		
	}()
	
}



extension MDLVertexDescriptor {
	var mtl: MTLVertexDescriptor {return MTKMetalVertexDescriptorFromModelIO(self)!}
}
extension MTLVertexDescriptor {
	var mdl: MDLVertexDescriptor {return MTKModelIOVertexDescriptorFromMetal(self)}
}
