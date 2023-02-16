import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque = lib.device.makeCommandQueue()!
	var scene: Scene
	init(scene: Scene) {
		self.scene = scene
	}
	
	let shadepipestate = lib.pipestate(
		vtxfn: lib.shader("vtx_shadow"),
		fmts: [
			-1: cfg.depth_fmt
	])
	let gbufpipestate = lib.pipestate(
		vtxfn: lib.shader("vtx_main"),
		frgfn: lib.shader("frg_gbuf"),
		fmts: lib.gbuffmts
	)
	let quadpipestate = lib.pipestate(
		vtxdescr: nil,
		vtxfn: lib.shader("vtx_quad"),
		frgfn: lib.shader("frg_gdir"),
		fmts: [0: cfg.color_fmt]
	)
	
	let shadepassdescr: MTLRenderPassDescriptor = {
		let descr = MTLRenderPassDescriptor()
		descr.depthAttachment.loadAction = .clear
		descr.depthAttachment.storeAction = .store
		descr.depthAttachment.texture = lib.texture(
			dim: uint2(cfg.shdqlt, cfg.shdqlt),
			fmt: cfg.depth_fmt,
			usage: [.shaderRead, .renderTarget]
		)
		return descr
	}()
	var gbufpassdescr = lib.passdescr(
		dim: uint2(uint(cfg.win_w), uint(cfg.win_h)),
		fmts: lib.gbuffmts
	)
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.cam.aspect = float(size.width) / float(size.height)
		self.gbufpassdescr = lib.passdescr(
			dim: uint2(uint(size.width), uint(size.height)),
			fmts: lib.gbuffmts
		)
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		
		buf.pass(label: "shade", descr: self.shadepassdescr) {
			enc in
			enc.setRenderPipelineState(self.shadepipestate)
			enc.setDepthStencilState(lib.depthstate)
			enc.setCullMode(.back)
			enc.setDepthBias(1e4, slopeScale: 1, clamp: 1)
			self.scene.lgt.svtx.render(enc: enc)
			self.scene.draw(enc: enc, material: false)
		}
		buf.pass(label: "gbuf", descr: self.gbufpassdescr) {
			enc in
			enc.setRenderPipelineState(self.gbufpipestate)
			enc.setDepthStencilState(lib.depthstate)
			enc.setCullMode(.front)
			enc.setFragmentTexture(self.shadepassdescr.depthAttachment.texture, index: 1)
			self.scene.cam.svtx.render(enc: enc)
			self.scene.sfrg.render(enc: enc)
			self.scene.draw(enc: enc, material: true)
		}
		buf.pass(label: "quad", descr: view.currentRenderPassDescriptor!) {
			enc in
			enc.setRenderPipelineState(self.quadpipestate)
			enc.setFragmentTexture(self.gbufpassdescr.colorAttachments[0].texture, index: 0)
			enc.setFragmentTexture(self.gbufpassdescr.colorAttachments[1].texture, index: 1)
			enc.setFragmentTexture(self.gbufpassdescr.colorAttachments[2].texture, index: 2)
			enc.setFragmentTexture(self.gbufpassdescr.colorAttachments[3].texture, index: 3)
			self.scene.sfrg.render(enc: enc)
			enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		}
		
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
}
