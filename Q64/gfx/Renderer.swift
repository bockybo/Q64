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
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		self.draw(in: view, with: buf)
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.res = uint2(
			uint(2 * size.width),
			uint(2 * size.height))
		self.scene.cam.asp = float(size.width / size.height)
		view.colorPixelFormat = Renderer.fmt_color
		view.depthStencilPixelFormat = Renderer.fmt_depth
		view.clearDepth = 1.0
	}
	
	
	static let fmt_gbuf_alb = MTLPixelFormat.rgba8Unorm
	static let fmt_gbuf_nml = MTLPixelFormat.rgba8Snorm
	static let fmt_gbuf_dep = MTLPixelFormat.rg32Float
	static let fmt_color = MTLPixelFormat.bgra8Unorm
	static let fmt_depth = MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade = MTLPixelFormat.depth32Float
	
	let shadepass: MTLRenderPassDescriptor = {
		let pass = MTLRenderPassDescriptor()
		pass.depthAttachment.loadAction  = .clear
		pass.depthAttachment.storeAction = .store
		pass.depthAttachment.texture = lib.texture(
			fmt: Renderer.fmt_shade,
			size: uint2(uint(cfg.shdqlt), uint(cfg.shdqlt)),
			storage: .private,
			usage: [.shaderRead, .renderTarget])
		return pass
	}()
	
	let lightpass: MTLRenderPassDescriptor = {
		let pass = MTLRenderPassDescriptor()
		pass.colorAttachments[0].storeAction 	= .store
		pass.colorAttachments[1].storeAction 	= .dontCare
		pass.colorAttachments[2].storeAction 	= .dontCare
		pass.colorAttachments[3].storeAction 	= .dontCare
		pass.depthAttachment.storeAction 		= .dontCare
		pass.stencilAttachment.storeAction 		= .dontCare
		pass.colorAttachments[0].loadAction		= .clear
		pass.colorAttachments[1].loadAction		= .clear
		pass.colorAttachments[2].loadAction		= .clear
		pass.colorAttachments[3].loadAction		= .clear
		pass.depthAttachment.loadAction  		= .clear
		pass.stencilAttachment.loadAction  		= .clear
		return pass
	}()
	var res = uint2(0, 0) {didSet {
		self.lightpass.colorAttachments[1].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_alb,
			size: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "alb+imf"
		)
		self.lightpass.colorAttachments[2].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_nml,
			size: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "nml+shd"
		)
		self.lightpass.colorAttachments[3].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_dep,
			size: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "dep"
		)
	}}
	
	let shadepipe = lib.pipestate(
		vtxdescr: "base",
		vtxshader: "vtx_shade"
	) { descr in
		descr.depthAttachmentPixelFormat = Renderer.fmt_shade
	}
	let gbufpipe = lib.pipestate(
		vtxdescr: "main",
		vtxshader: "vtx_gbuf",
		frgshader: "frg_gbuf"
	) { descr in
		descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
		descr.colorAttachments[0].pixelFormat 	= Renderer.fmt_color
		descr.colorAttachments[1].pixelFormat 	= Renderer.fmt_gbuf_alb
		descr.colorAttachments[2].pixelFormat 	= Renderer.fmt_gbuf_nml
		descr.colorAttachments[3].pixelFormat 	= Renderer.fmt_gbuf_dep
	}
	let quadpipe = lib.pipestate(
		vtxshader: "vtx_quad",
		frgshader: "frg_light"
	) { descr in
		descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
		descr.colorAttachments[0].pixelFormat 	= Renderer.fmt_color
		descr.colorAttachments[1].pixelFormat 	= Renderer.fmt_gbuf_alb
		descr.colorAttachments[2].pixelFormat 	= Renderer.fmt_gbuf_nml
		descr.colorAttachments[3].pixelFormat 	= Renderer.fmt_gbuf_dep
	}
	let icospipe = lib.pipestate(
		vtxshader: "vtx_icos",
		frgshader: "frg_light"
	) { descr in
		descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
		descr.colorAttachments[0].pixelFormat 	= Renderer.fmt_color
		descr.colorAttachments[1].pixelFormat 	= Renderer.fmt_gbuf_alb
		descr.colorAttachments[2].pixelFormat 	= Renderer.fmt_gbuf_nml
		descr.colorAttachments[3].pixelFormat 	= Renderer.fmt_gbuf_dep
//		descr..isBlendingEnabled				= true
//		descr..rgbBlendOperation				= .add
//		descr..sourceRGBBlendFactor				= .one
//		descr..destinationRGBBlendFactor 		= .one
//		descr..alphaBlendOperation				= .add
//		descr..sourceAlphaBlendFactor			= .one
//		descr..destinationAlphaBlendFactor		= .one
	}
	
	let shadedepth = lib.depthstate(wrt: true, cmp: .lessEqual)
	let gbufdepth = lib.depthstate(wrt: true, cmp: .less)
	let quaddepth = lib.depthstate(wrt: false)
	let icosdepth = lib.depthstate(wrt: false)
	
	private func draw(in view: MTKView, with buf: MTLCommandBuffer) {
		self.lightpass.colorAttachments[0].texture	= view.currentDrawable!.texture
		self.lightpass.depthAttachment.texture		= view.depthStencilTexture!
		self.lightpass.stencilAttachment.texture	= view.depthStencilTexture!
		buf.pass(label: "shade", descr: self.shadepass) {enc in self.drawshade(enc: enc)}
		buf.pass(label: "light", descr: self.lightpass) {enc in self.drawlight(enc: enc)}
	}
	private func drawshade(enc: MTLRenderCommandEncoder) {
		enc.setState(self.shadepipe, self.shadedepth, cull: .front)
		enc.setDepthBias(0.015, slopeScale: 7, clamp: 0.02)
		var ctm = self.scene.lgt.ctm
		enc.setVertexBytes(&ctm, length: sizeof(ctm), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		for mdl in self.scene.mdls {
			for mesh in mdl.meshes {
				enc.draw(mesh, prim: mdl.prim, iid: mdl.iid, nid: mdl.nid)
			}
		}
	}
	private func drawlight(enc: MTLRenderCommandEncoder) {
		enc.setStencilReferenceValue(128)
		self.rendergbuf(enc: enc)
		var cam = self.scene.cam.ctm
		var invproj = self.scene.cam.proj.inverse
		var invview = self.scene.cam.view
		enc.setVertexBytes(&cam, length: sizeof(cam), index: 3)
		enc.setFragmentBytes(&invproj, length: sizeof(invproj), index: 3)
		enc.setFragmentBytes(&invview, length: sizeof(invview), index: 4)
		enc.setFragmentBytes(&self.res, length: sizeof(self.res), index: 5)
		self.renderquad(enc: enc)
//		self.rendericos(enc: enc)
	}
	
	private func rendergbuf(enc: MTLRenderCommandEncoder) {
		enc.setState(self.gbufpipe, self.gbufdepth, cull: .front)
		var camctm = self.scene.cam.ctm
		var lgtctm = self.scene.lgt.ctm
		enc.setVertexBytes(&camctm, length: sizeof(camctm), index: 3)
		enc.setVertexBytes(&lgtctm, length: sizeof(lgtctm), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		enc.setFragmentTexture(self.shadepass.depthAttachment.texture!, index: 1)
		for mdl in self.scene.mdls {
			enc.setFragmentTexture(mdl.tex, index: 0)
			for mesh in mdl.meshes {
				enc.draw(mesh, prim: mdl.prim, iid: mdl.iid, nid: mdl.nid)
			}
		}
	}
	
	private func renderquad(enc: MTLRenderCommandEncoder) {
		enc.setState(self.quadpipe, self.quaddepth, cull: .none)
		var lgt = self.scene.lgt.lfrg
		enc.setFragmentBytes(&lgt, length: sizeof(lgt), index: 2)
		enc.setFragmentBuffer(self.scene.mfrgs.buf, offset: 0, index: 1)
		enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
	}
	private func rendericos(enc: MTLRenderCommandEncoder) {
		enc.setState(self.icospipe, self.icosdepth, cull: .none)
		enc.setVertexBuffer(self.scene.lfrgs.buf, offset: 0, index: 2)
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
	
	func draw(_ mesh: MTKMesh, prim: MTLPrimitiveType = .triangle, iid: Int = 0, nid: Int = 1) {
		for buf in mesh.vertexBuffers {
			self.setVertexBuffer(buf.buffer, offset: buf.offset, index: 0)
			for sub in mesh.submeshes {
				self.drawIndexedPrimitives(
					type:				prim,
					indexCount:			sub.indexCount,
					indexType:			sub.indexType,
					indexBuffer:		sub.indexBuffer.buffer,
					indexBufferOffset:	sub.indexBuffer.offset,
					instanceCount:		nid,
					baseVertex:			0,
					baseInstance: 		iid
				)
			}
		}
	}
	
	func setState(
		_ state: MTLRenderPipelineState,
		_ depth: MTLDepthStencilState,
		cull: MTLCullMode = .none
	) {
		self.setRenderPipelineState(state)
		self.setDepthStencilState(depth)
		self.setCullMode(cull)
	}
	
}
