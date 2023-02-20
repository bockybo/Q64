import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	private let gpulock = DispatchSemaphore(value: 1)
	private let cmdque = lib.device.makeCommandQueue()!
	private var scene: Scene
	init(_ view: RenderView) {
		self.scene = view.ctrl.scene
		super.init()
		self.mtkView(view, drawableSizeWillChange: view.frame.size)
		view.preferredFramesPerSecond = cfg.fps
		view.delegate = self
	}
	
	var shadepass: MTLRenderPassDescriptor!
	var gbuffpass: MTLRenderPassDescriptor!
	var lightpass: MTLRenderPassDescriptor!
	var shadepipe: MTLRenderPipelineState!
	var gbuffpipe: MTLRenderPipelineState!
	var quadpipe: MTLRenderPipelineState!
	var maskpipe: MTLRenderPipelineState!
	var lpospipe: MTLRenderPipelineState!
	var shadedep: MTLDepthStencilState!
	var gbuffdep: MTLDepthStencilState!
	var quaddep: MTLDepthStencilState!
	var maskdep: MTLDepthStencilState!
	var lposdep: MTLDepthStencilState!
	
	func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {
		let w = view.frame.size.width
		let h = view.frame.size.height
		
		self.scene.cam.asp = float(w) / float(h)
		
		let color_fmt = MTLPixelFormat.bgra8Unorm
		let depth_fmt = MTLPixelFormat.depth32Float
		let stencil_fmt = MTLPixelFormat.depth32Float_stencil8
		
		self.shadepass = MTLRenderPassDescriptor()
		self.gbuffpass = MTLRenderPassDescriptor()
		self.lightpass = MTLRenderPassDescriptor()
		
		
		self.gbuffpass.stencilAttachment.storeAction = .store
		self.lightpass.stencilAttachment.loadAction	= .load
		self.gbuffpass.depthAttachment.storeAction = .store
		self.lightpass.depthAttachment.loadAction = .load
		
		self.lightpass.colorAttachments[0].loadAction = .clear
		self.lightpass.colorAttachments[0].storeAction = .store
		
		self.shadepass.depthAttachment.loadAction  = .clear
		self.shadepass.depthAttachment.storeAction = .store
		self.shadepass.depthAttachment.texture = lib.texture(
			fmt: depth_fmt,
			size: uint2(uint(cfg.shdqlt), uint(cfg.shdqlt)),
			storage: .private,
			usage: [.shaderRead, .renderTarget])
		
		self.gbuffpass.colorAttachments[0].loadAction  = .clear
		self.gbuffpass.colorAttachments[0].storeAction = .store
		self.gbuffpass.colorAttachments[0].texture = lib.texture(
			fmt: color_fmt,
			size: uint2(uint(2 * w), uint(2 * h)),
			usage: [.shaderRead, .renderTarget])
		
		self.gbuffpass.colorAttachments[1].loadAction  = .clear
		self.gbuffpass.colorAttachments[1].storeAction = .store
		self.gbuffpass.colorAttachments[1].texture = lib.texture(
			fmt: .rgba8Snorm,
			size: uint2(uint(2 * w), uint(2 * h)),
			usage: [.shaderRead, .renderTarget])
		
		self.gbuffpass.colorAttachments[2].loadAction  = .clear
		self.gbuffpass.colorAttachments[2].storeAction = .store
		self.gbuffpass.colorAttachments[2].texture = lib.texture(
			fmt: .rgba32Float,
			size: uint2(uint(2 * w), uint(2 * h)),
			usage: [.shaderRead, .renderTarget])
		
		let shadepipe = MTLRenderPipelineDescriptor()
		let gbuffpipe = MTLRenderPipelineDescriptor()
		let quadpipe = MTLRenderPipelineDescriptor()
		let maskpipe = MTLRenderPipelineDescriptor()
		let lpospipe = MTLRenderPipelineDescriptor()
		
		
		shadepipe.vertexDescriptor = lib.mtkvtxdescrs["base"]!
		gbuffpipe.vertexDescriptor = lib.mtkvtxdescrs["main"]!
		quadpipe.vertexDescriptor = nil
		maskpipe.vertexDescriptor = nil
		lpospipe.vertexDescriptor = nil
		
		shadepipe.vertexFunction = lib.vtxshaders["shdw"]
		gbuffpipe.vertexFunction = lib.vtxshaders["main"]
		quadpipe.vertexFunction = lib.vtxshaders["quad"]
		maskpipe.vertexFunction = lib.vtxshaders["mask"]
		lpospipe.vertexFunction = lib.vtxshaders["lpos"]
		
		shadepipe.fragmentFunction = nil
		gbuffpipe.fragmentFunction = lib.frgshaders["main"]
		quadpipe.fragmentFunction = lib.frgshaders["light"]
		maskpipe.fragmentFunction = nil
		lpospipe.fragmentFunction = lib.frgshaders["light"]
		
		gbuffpipe.stencilAttachmentPixelFormat = stencil_fmt
		quadpipe.stencilAttachmentPixelFormat = stencil_fmt
		maskpipe.stencilAttachmentPixelFormat = stencil_fmt
		lpospipe.stencilAttachmentPixelFormat = stencil_fmt
		
		shadepipe.depthAttachmentPixelFormat = self.shadepass.depthAttachment.texture!.pixelFormat
		gbuffpipe.depthAttachmentPixelFormat = stencil_fmt
		quadpipe.depthAttachmentPixelFormat = stencil_fmt
		maskpipe.depthAttachmentPixelFormat = stencil_fmt
		lpospipe.depthAttachmentPixelFormat = stencil_fmt
		
		gbuffpipe.colorAttachments[0].pixelFormat = self.gbuffpass.colorAttachments[0].texture!.pixelFormat
		maskpipe.colorAttachments[0].pixelFormat = color_fmt
		quadpipe.colorAttachments[0].pixelFormat = color_fmt
		lpospipe.colorAttachments[0].pixelFormat = color_fmt
		
		gbuffpipe.colorAttachments[1].pixelFormat = self.gbuffpass.colorAttachments[1].texture!.pixelFormat
		gbuffpipe.colorAttachments[2].pixelFormat = self.gbuffpass.colorAttachments[2].texture!.pixelFormat
		
		lpospipe.colorAttachments[0].isBlendingEnabled				= true
		lpospipe.colorAttachments[0].rgbBlendOperation				= .add
		lpospipe.colorAttachments[0].sourceRGBBlendFactor			= .one
		lpospipe.colorAttachments[0].destinationRGBBlendFactor 		= .one
		lpospipe.colorAttachments[0].alphaBlendOperation			= .add
		lpospipe.colorAttachments[0].sourceAlphaBlendFactor			= .one
		lpospipe.colorAttachments[0].destinationAlphaBlendFactor	= .one
		
		self.shadepipe = try! lib.device.makeRenderPipelineState(descriptor: shadepipe)
		self.gbuffpipe = try! lib.device.makeRenderPipelineState(descriptor: gbuffpipe)
		self.quadpipe = try! lib.device.makeRenderPipelineState(descriptor: quadpipe)
		self.maskpipe = try! lib.device.makeRenderPipelineState(descriptor: maskpipe)
		self.lpospipe = try! lib.device.makeRenderPipelineState(descriptor: lpospipe)
		
		let shadedep = MTLDepthStencilDescriptor()
		let gbuffdep = MTLDepthStencilDescriptor()
		let quaddep = MTLDepthStencilDescriptor()
		let maskdep = MTLDepthStencilDescriptor()
		let lposdep = MTLDepthStencilDescriptor()
		
		shadedep.isDepthWriteEnabled = true
		shadedep.depthCompareFunction = .lessEqual
		
		gbuffdep.isDepthWriteEnabled = true
		gbuffdep.depthCompareFunction = .less
		gbuffdep.frontFaceStencil = MTLStencilDescriptor()
		gbuffdep.frontFaceStencil.depthStencilPassOperation = .replace
		gbuffdep.backFaceStencil = gbuffdep.frontFaceStencil
		
		quaddep.frontFaceStencil = MTLStencilDescriptor()
		quaddep.frontFaceStencil.stencilCompareFunction = .equal
		quaddep.frontFaceStencil.readMask = 0xFF
		quaddep.frontFaceStencil.writeMask = 0x0
		quaddep.backFaceStencil = quaddep.frontFaceStencil
		
		maskdep.depthCompareFunction = .lessEqual
		maskdep.frontFaceStencil = MTLStencilDescriptor()
		maskdep.frontFaceStencil.depthFailureOperation = .incrementClamp
		maskdep.backFaceStencil = maskdep.frontFaceStencil
	
		lposdep.depthCompareFunction = .greaterEqual
		lposdep.frontFaceStencil = MTLStencilDescriptor()
		lposdep.frontFaceStencil.stencilCompareFunction = .less
		lposdep.frontFaceStencil.readMask = 0xFF
		lposdep.frontFaceStencil.writeMask = 0x0
		lposdep.backFaceStencil = lposdep.frontFaceStencil
		
		self.shadedep = lib.device.makeDepthStencilState(descriptor: shadedep)!
		self.gbuffdep = lib.device.makeDepthStencilState(descriptor: gbuffdep)!
		self.quaddep = lib.device.makeDepthStencilState(descriptor: quaddep)!
		self.maskdep = lib.device.makeDepthStencilState(descriptor: maskdep)!
		self.lposdep = lib.device.makeDepthStencilState(descriptor: lposdep)!
		
		view.colorPixelFormat = color_fmt
		view.depthStencilPixelFormat = stencil_fmt
		
	}
	
	func draw(in view: MTKView) {
		let drawable = view.currentDrawable!
		let depthtex = view.depthStencilTexture!
		self.gbuffpass.depthAttachment.texture = depthtex
		self.lightpass.depthAttachment.texture = depthtex
		self.gbuffpass.stencilAttachment.texture = depthtex
		self.lightpass.stencilAttachment.texture = depthtex
		self.lightpass.colorAttachments[0].texture = drawable.texture
		
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		
		buf.pass(label: "shade", descr: self.shadepass) {enc in
			self.rendershdw(enc: enc)
		}
		buf.pass(label: "gbuff", descr: self.gbuffpass) {enc in
			enc.setFragmentTexture(self.shadepass.depthAttachment.texture, index: 1)
			enc.setStencilReferenceValue(128)
			self.rendergbuf(enc: enc)
		}
		buf.pass(label: "light", descr: self.lightpass) {enc in
			enc.setFragmentTexture(self.gbuffpass.colorAttachments[0].texture!, index: 0)
			enc.setFragmentTexture(self.gbuffpass.colorAttachments[1].texture!, index: 1)
			enc.setFragmentTexture(self.gbuffpass.colorAttachments[2].texture!, index: 2)
			enc.setStencilReferenceValue(128)
			self.renderquad(enc: enc)
			self.rendermask(enc: enc)
			self.renderlpos(enc: enc)
		}
		
		buf.present(drawable)
		buf.commit()
		
	}
	
	private func rendershdw(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.shadepipe)
		enc.setDepthStencilState(self.shadedep)
		enc.setCullMode(.front)
		enc.setDepthBias(0.015, slopeScale: 7, clamp: 0.02)
		var ctm = self.scene.lgt.ctm
		enc.setVertexBytes(&ctm, length: sizeof(ctm), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		self.drawscene(enc: enc, textured: false)
	}
	private func rendergbuf(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.gbuffpipe)
		enc.setDepthStencilState(self.gbuffdep)
		enc.setCullMode(.front)
		var camctm = self.scene.cam.ctm
		var lgtctm = self.scene.lgt.ctm
		enc.setVertexBytes(&camctm, length: sizeof(camctm), index: 3)
		enc.setVertexBytes(&lgtctm, length: sizeof(lgtctm), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		self.drawscene(enc: enc, textured: true)
	}
	private func renderquad(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.quadpipe)
		enc.setDepthStencilState(self.quaddep)
		var eye = self.scene.cam.pos
		var lgt = self.scene.lgt.lfrg
		enc.setFragmentBytes(&eye, length: sizeof(eye), index: 3)
		enc.setFragmentBytes(&lgt, length: sizeof(lgt), index: 2)
		enc.setFragmentBuffer(self.scene.mfrgs.buf, offset: 0, index: 1)
		enc.draw(6)
	}
	private func rendermask(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.maskpipe)
		enc.setDepthStencilState(self.maskdep)
		enc.setCullMode(.back)
		self.drawd20(enc: enc)
	}
	private func renderlpos(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.lpospipe)
		enc.setDepthStencilState(self.lposdep)
		enc.setCullMode(.back)
		self.drawd20(enc: enc)
	}
	
	private func drawscene(enc: MTLRenderCommandEncoder, textured: Bool) {
		for mdl in self.scene.mdls {
			enc.setVertexBufferOffset(mdl.iid * sizeof(MVTX.self), index: 1)
			if textured {enc.setFragmentTexture(mdl.tex, index: 0)}
			for mesh in mdl.meshes {
				enc.draw(mesh, num: mdl.nid, prim: mdl.prim)
			}
		}
	}
	private func drawd20(enc: MTLRenderCommandEncoder) {
		var cam = self.scene.cam.ctm
		var eye = self.scene.cam.pos
		enc.setVertexBytes(&cam, length: sizeof(cam), index: 3)
		enc.setVertexBuffer(self.scene.lfrgs.buf, offset: 0, index: 2)
		enc.setFragmentBytes(&eye, length: sizeof(eye), index: 3)
		enc.setFragmentBuffer(self.scene.lfrgs.buf, offset: 0, index: 2)
		enc.setFragmentBuffer(self.scene.mfrgs.buf, offset: 0, index: 1)
		enc.draw(self.scene.d20mesh)
	}
	
}


extension MTLCommandBuffer {
	
	func pass(label: String, descr: MTLRenderPassDescriptor, _ cmds: (MTLRenderCommandEncoder)->()) {
		let enc = self.makeRenderCommandEncoder(descriptor: descr)!
		enc.label = label
		enc.pushDebugGroup(label)
		cmds(enc)
		enc.popDebugGroup()
		enc.endEncoding()
	}
	
}

extension MTLRenderCommandEncoder {
	
	func draw(_ mesh: MTKMesh, num: Int = 1, prim: MTLPrimitiveType = .triangle) {
		for buf in mesh.vertexBuffers {
			self.setVertexBuffer(buf.buffer, offset: buf.offset, index: 0)
			for sub in mesh.submeshes {
				self.drawIndexedPrimitives(
					type:				prim,
					indexCount:			sub.indexCount,
					indexType:			sub.indexType,
					indexBuffer:		sub.indexBuffer.buffer,
					indexBufferOffset:	sub.indexBuffer.offset,
					instanceCount:		num
				)
			}
		}
	}
	
	func draw(_ n: Int, prim: MTLPrimitiveType = .triangle) {
		self.drawPrimitives(type: prim, vertexStart: 0, vertexCount: n)
	}
	
}
