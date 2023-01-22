import MetalKit


class RenderView: MTKView {
	var ctrl: Controller!
	var renderer: Renderer {return self.delegate as! Renderer}
	
	required init(coder: NSCoder) {
		super.init(coder: coder)
		self._init()
	}
	override init(frame: CGRect, device: MTLDevice?) {
		super.init(frame: frame, device: device)
		self._init()
	}
	
	private func _init() {
		
		self.colorPixelFormat = Config.color_fmt
		self.depthStencilPixelFormat = Config.depth_fmt
		self.preferredFramesPerSecond = Config.fps
		
		self.ctrl = Controller(device: self.device!)
		let clock = CtrlClock(ctrl: self.ctrl)
		clock.run()
		
	}
	
	override var acceptsFirstResponder: Bool {return true}
	override func keyDown(with evt: NSEvent) {
		if evt.isARepeat {return}
		guard let key = Keystroke(rawValue: evt.keyCode) else {return}
		self.ctrl.binds.keydn[key]?()
	}
	override func keyUp(with evt: NSEvent) {
		guard let key = Keystroke(rawValue: evt.keyCode) else {return}
		self.ctrl.binds.keyup[key]?()
	}
	
	override func mouseDown			(with evt: NSEvent) {self.ctrl.binds.btndn[evt.buttonNumber]?()}
	override func mouseUp			(with evt: NSEvent) {self.ctrl.binds.btnup[evt.buttonNumber]?()}
	override func mouseDragged		(with evt: NSEvent) {self.ctrl.binds.btndrag[evt.buttonNumber]?()}
	override func rightMouseDown	(with evt: NSEvent) {self.ctrl.binds.btndn[evt.buttonNumber]?()}
	override func rightMouseUp		(with evt: NSEvent) {self.ctrl.binds.btnup[evt.buttonNumber]?()}
	override func rightMouseDragged	(with evt: NSEvent) {self.ctrl.binds.btndrag[evt.buttonNumber]?()}
	
}
