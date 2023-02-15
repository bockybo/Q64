import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque = lib.device.makeCommandQueue()!
	var scene: Scene?
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene?.cam.aspect = float(size.width) / float(size.height)
	}
	
	func draw(in view: MTKView) {
		guard let scene = self.scene else {return}
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		buf.pass(label: "shade", descr: lib.shadepassdescr(self.shademap)) {
			enc in
			enc.setDepthStencilState(lib.depthstate)
			enc.setRenderPipelineState(lib.shadepipestate)
			enc.setDepthBias(30, slopeScale: 1, clamp: 1)
			scene.shade(enc: enc)
		}
		buf.pass(label: "light", descr: view.currentRenderPassDescriptor!) {
			enc in
			enc.setDepthStencilState(lib.depthstate)
			enc.setRenderPipelineState(lib.lightpipestate)
			enc.setFragmentTexture(self.shademap, index: 1)
			scene.light(enc: enc)
		}
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
	let shademap: MTLTexture = {
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: cfg.depth_fmt,
			width:  cfg.shdqlt,
			height: cfg.shdqlt,
			mipmapped: false
		)
		descr.storageMode = .private
		descr.usage = [.renderTarget, .shaderRead]
		return lib.device.makeTexture(descriptor: descr)!
	}()
	
}
