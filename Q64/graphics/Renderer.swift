import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque: MTLCommandQueue
	let rstate: MTLRenderPipelineState
	let dstate: MTLDepthStencilState
	let scene: Scene
	
	init(device: MTLDevice, scene: Scene) {
		
		self.cmdque = device.makeCommandQueue()!
		
		let ddescr = MTLDepthStencilDescriptor()
		ddescr.isDepthWriteEnabled = true
		ddescr.depthCompareFunction = .less
		self.dstate = device.makeDepthStencilState(descriptor: ddescr)!
		
		let descr = MTLRenderPipelineDescriptor()
		descr.vertexDescriptor = Renderer.mtldescr
		descr.colorAttachments[0].pixelFormat	= Config.color_fmt
		descr.depthAttachmentPixelFormat		= Config.depth_fmt
		
		descr.colorAttachments[0].isBlendingEnabled				= true
		descr.colorAttachments[0].rgbBlendOperation				= .add
		descr.colorAttachments[0].alphaBlendOperation			= .add
		descr.colorAttachments[0].sourceRGBBlendFactor			= .sourceAlpha
		descr.colorAttachments[0].sourceAlphaBlendFactor		= .sourceAlpha
		descr.colorAttachments[0].destinationRGBBlendFactor		= .oneMinusSourceAlpha
		descr.colorAttachments[0].destinationAlphaBlendFactor	= .oneMinusSourceAlpha
		
		let lib = device.makeDefaultLibrary()!
		descr.vertexFunction	= lib.makeFunction(name: Config.vtxfn)!
		descr.fragmentFunction	= lib.makeFunction(name: Config.frgfn)!
		
		self.rstate = try! device.makeRenderPipelineState(descriptor: descr)
		
		self.scene = scene
		super.init()
		
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		let enc = buf.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
		
		enc.setRenderPipelineState(self.rstate)
		enc.setDepthStencilState(self.dstate)
		
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		
		self.scene.render(enc: enc)
		
		enc.endEncoding()
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.aspect = f32(size.width / size.height)
	}
	
	
	static let mdldescr: MDLVertexDescriptor = {
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
	static let mtldescr: MTLVertexDescriptor = {
		return MTKMetalVertexDescriptorFromModelIO(Renderer.mdldescr)!
	}()
	
}
