import MetalKit


class RenderView: MTKView {
	let ctrl = Demo()
	
	override var acceptsFirstResponder: Bool {return true}
	
	override func keyDown				(with evt: NSEvent) {self.key(evt)?.dn()}
	override func keyUp					(with evt: NSEvent) {self.key(evt)?.up()}
	
	override func mouseDown				(with evt: NSEvent) {self.btn(evt)?.dn()}
	override func mouseUp				(with evt: NSEvent) {self.btn(evt)?.up()}
	override func rightMouseDown		(with evt: NSEvent) {self.btn(evt)?.dn()}
	override func rightMouseUp			(with evt: NSEvent) {self.btn(evt)?.up()}
	override func otherMouseDown		(with evt: NSEvent) {self.btn(evt)?.dn()}
	override func otherMouseUp			(with evt: NSEvent) {self.btn(evt)?.up()}
	
	override func mouseMoved			(with evt: NSEvent) {self.ptr(evt)}
	override func mouseDragged			(with evt: NSEvent) {self.ptr(evt)}
	override func rightMouseDragged		(with evt: NSEvent) {self.ptr(evt)}
	override func otherMouseDragged		(with evt: NSEvent) {self.ptr(evt)}
	
	private func key(_ evt: NSEvent) -> Binds.keybind? {
		if evt.isARepeat {return nil}
		guard let key = Keystroke(rawValue: evt.keyCode) else {return nil}
		return self.ctrl.binds.key[key]
	}
	private func btn(_ evt: NSEvent) -> Binds.keybind? {
		let btn = evt.buttonNumber
		guard let btnbind = self.ctrl.binds.btn[btn] else {return nil}
		let raw = evt.locationInWindow
		let loc = float2(float(raw.x), float(raw.y))
		return (dn: {btnbind.dn(loc)}, up: {btnbind.up(loc)})
	}
	private func ptr(_ evt: NSEvent) {
		let btn = (NSEvent.pressedMouseButtons > 0) ? evt.buttonNumber : -1
		let mov = float2(float(evt.deltaX), float(evt.deltaY))
		self.ctrl.binds.ptr[btn]?(mov)
	}
	
}
