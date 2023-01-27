import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque: MTLCommandQueue
	let scene: Scene
	
	init(scene: Scene) {
		self.scene = scene
		self.cmdque = lib.device.makeCommandQueue()!
		super.init()
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.cam.aspect = f32(size.width) / f32(size.height)
	}
	
	func draw(in view: MTKView) {
		
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		
		var enc: MTLRenderCommandEncoder
		
		let descr = lib.shadepassdescr
		descr.depthAttachment.texture = self.scene.lgt.shdmap
		
		enc = buf.makeRenderCommandEncoder(descriptor: descr)!
		enc.setRenderPipelineState(lib.shadepipestate)
		enc.setDepthStencilState(lib.depthstate)
		self.scene.shade(enc: enc)
		enc.endEncoding()
		
		enc = buf.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
		enc.setRenderPipelineState(lib.lightpipestate)
		enc.setDepthStencilState(lib.depthstate)
		enc.setFragmentTexture(self.scene.lgt.shdmap, index: 1)
		self.scene.light(enc: enc)
		enc.endEncoding()
		
		buf.present(view.currentDrawable!)
		buf.commit()
		
	}
	
}
