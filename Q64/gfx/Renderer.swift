import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque = lib.device.makeCommandQueue()!
	var scene: Scene
	init(_ view: RenderView) {
		self.scene = view.ctrl.scene
		view.preferredFramesPerSecond = cfg.fps
		view.colorPixelFormat = cfg.color_fmt
		super.init()
		view.delegate = self
		self.mtkView(view, drawableSizeWillChange: CGSize(
			width:  2 * view.frame.width,
			height: 2 * view.frame.height
		))
	}
	
	let shdwpipe = lib.pipestate(
		vtxshader: lib.vtxshaders["shdw"],
		fmts: [-1: cfg.depth_fmt])
	var shdwpass = lib.passdescr(
		fmts: [-1: cfg.depth_fmt],
		size: uint2(cfg.shdqlt, cfg.shdqlt))
	let gbufpipe = lib.pipestate(
		vtxshader: lib.vtxshaders["main"],
		frgshader: lib.frgshaders["main"],
		fmts: cfg.gbuf_fmts)
	var gbufpass = lib.passdescr(
		fmts: cfg.gbuf_fmts,
		size: uint2(uint(cfg.win_w), uint(cfg.win_h)))
	let quadpipe = lib.pipestate(
		vtxdescr: nil,
		vtxshader: lib.vtxshaders["quad"],
		frgshader: lib.frgshaders["quad"],
		fmts: [0: cfg.color_fmt])
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.cam.aspect = float(size.width) / float(size.height)
		self.gbufpass = lib.passdescr(
			fmts: cfg.gbuf_fmts,
			size: uint2(uint(size.width), uint(size.height)))
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		buf.pass(label: "shdw", descr: self.shdwpass) {enc in self.rendershdw(enc: enc)}
		buf.pass(label: "gbuf", descr: self.gbufpass) {enc in self.rendergbuf(enc: enc)}
		buf.pass(label: "quad", descr: view.currentRenderPassDescriptor!) {enc in self.renderquad(enc: enc)}
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
	private func rendershdw(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.shdwpipe)
		enc.setDepthStencilState(lib.depthstate)
		enc.setCullMode(.back)
//		enc.setDepthBias(0.015, slopeScale: 7, clamp: 0.02)
		var ctm = self.scene.lgt.ctm
		enc.setVertexBytes(&ctm, length: sizeof(ctm), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		self.drawloop(enc: enc, textured: false)
	}
	private func rendergbuf(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.gbufpipe)
		enc.setDepthStencilState(lib.depthstate)
		enc.setCullMode(.front)
		enc.setFragmentTexture(self.shdwpass.depthAttachment.texture, index: 1)
		var svtx = self.scene.svtx
		enc.setVertexBytes(&svtx, length: sizeof(svtx), index: 2)
		enc.setVertexBuffer(self.scene.mvtcs.buf, offset: 0, index: 1)
		self.drawloop(enc: enc, textured: true)
	}
	private func renderquad(enc: MTLRenderCommandEncoder) {
		enc.setRenderPipelineState(self.quadpipe)
		enc.setFragmentTexture(self.gbufpass.colorAttachments[0].texture!, index: 0)
		enc.setFragmentTexture(self.gbufpass.colorAttachments[1].texture!, index: 1)
		enc.setFragmentTexture(self.gbufpass.colorAttachments[2].texture!, index: 2)
		var sfrg = self.scene.sfrg
		enc.setFragmentBytes(&sfrg, length: sizeof(sfrg), index: 2)
		enc.setFragmentBuffer(self.scene.mfrgs.buf, offset: 0, index: 1)
		enc.draw(6)
	}
	
	private func drawloop(enc: MTLRenderCommandEncoder, textured: Bool) {
//		var n = 0
//		for mdl in self.scene.mdls {
//			enc.setVertexBufferOffset(n * sizeof(MVTX.self), index: 1)
//			if textured {enc.setFragmentTexture(mdl.tex, index: 0)}
//			for mesh in mdl.meshes {
//				enc.draw(mesh, prim: mdl.prim, num: mdl.inst)
//			}
//			n += mdl.inst
//		}
		for mdl in self.scene.mdls {
			let i = mdl.ids.lowerBound
			let n = mdl.ids.upperBound - i
			enc.setVertexBufferOffset(i * sizeof(MVTX.self), index: 1)
			if textured {enc.setFragmentTexture(mdl.tex, index: 0)}
			for mesh in mdl.meshes {
				enc.draw(mesh, prim: mdl.prim, num: n)
			}
		}
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
	
	func draw(_ mesh: MTKMesh, prim: MTLPrimitiveType = .triangle, num: Int = 1) {
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
	
	func draw(_ n: Int, type: MTLPrimitiveType = .triangle) {
		self.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
	}
	
}
