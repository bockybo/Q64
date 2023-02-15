import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque = lib.device.makeCommandQueue()!
	var scene: Scene
	init(scene: Scene) {
		self.scene = scene
	}
	
	let lightpipestate = lib.pipestate("vtx_light", frgfn: "frg_main")
	let shadepipestate = lib.pipestate("vtx_shade", color: false)
	let shadepassdescr = lib.passdescr(
		[-1: lib.texture(dim: uint2(cfg.shdqlt, cfg.shdqlt), fmt: cfg.depth_fmt, usage: [.shaderRead, .renderTarget])]
	)
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.cam.aspect = float(size.width) / float(size.height)
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		buf.pass(label: "shade", descr: self.shadepassdescr) {
			enc in
			enc.setDepthStencilState(lib.depthstate)
			enc.setRenderPipelineState(self.shadepipestate)
			enc.setDepthBias(5, slopeScale: 1, clamp: 1)
			self.scene.shade(enc: enc)
		}
		buf.pass(label: "light", descr: view.currentRenderPassDescriptor!) {
			enc in
			enc.setDepthStencilState(lib.depthstate)
			enc.setRenderPipelineState(self.lightpipestate)
			enc.setFragmentTexture(self.shadepassdescr.depthAttachment.texture, index: 1)
			self.scene.light(enc: enc)
		}
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
}
