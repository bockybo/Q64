import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque: MTLCommandQueue
	let scene: Scene
	
	init(scene: Scene) {
		self.cmdque = lib.device.makeCommandQueue()!
		self.scene = scene
		super.init()
	}
	
	func draw(in view: MTKView) {
		
		let buf = self.cmdque.makeCommandBuffer()!
		let enc = buf.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
		
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		
		enc.setRenderPipelineState(lib.rdpstate)
		enc.setDepthStencilState(lib.depstate)
		enc.setFragmentSamplerState(lib.smpstate, index: 0)
		
		self.scene.render(enc: enc)
		
		enc.endEncoding()
		buf.present(view.currentDrawable!)
		buf.commit()
		
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.scene.aspect = f32(size.width / size.height)
	}
	
}
