import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	let gpulock = DispatchSemaphore(value: 1)
	let cmdque: MTLCommandQueue
	let dstate: MTLDepthStencilState
	let scene: Scene
	
	init(device: MTLDevice, scene: Scene) {
		self.cmdque = device.makeCommandQueue()!
		self.dstate = lib.dstate(device)
		self.scene = scene
		super.init()
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		let enc = buf.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!
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
	
}
