import Cocoa


class CtrlView: NSView {
	var ctrl: Ctrl!
	
	var timer: Timer? = nil
	func start(tps: Int, scene: Scene) {
		var t0 = DispatchTime.now().uptimeNanoseconds
		self.timer = Timer(timeInterval: 1/Double(tps), repeats: true) {_ in
			let t1 = DispatchTime.now().uptimeNanoseconds
			let dt = t1 - t0
			t0 = t1
			self.ctrl.tick(scene: scene, dt: float(dt))
		}
		RunLoop.main.add(self.timer!, forMode: .default)
	}
	func stop() {
		self.timer?.invalidate()
		self.timer = nil
	}
	
	override var acceptsFirstResponder: Bool {return true}
	
	override func keyDown				(with evt: NSEvent) {self.ctrl.binds.onkeydn(evt)}
	override func keyUp					(with evt: NSEvent) {self.ctrl.binds.onkeyup(evt)}

	override func mouseDown				(with evt: NSEvent) {self.ctrl.binds.onbtndn(evt)}
	override func mouseUp				(with evt: NSEvent) {self.ctrl.binds.onbtnup(evt)}
	override func rightMouseDown		(with evt: NSEvent) {self.ctrl.binds.onbtndn(evt)}
	override func rightMouseUp			(with evt: NSEvent) {self.ctrl.binds.onbtnup(evt)}
	override func otherMouseDown		(with evt: NSEvent) {self.ctrl.binds.onbtndn(evt)}
	override func otherMouseUp			(with evt: NSEvent) {self.ctrl.binds.onbtnup(evt)}

	override func mouseMoved			(with evt: NSEvent) {self.ctrl.binds.onmov(evt)}
	override func mouseDragged			(with evt: NSEvent) {self.ctrl.binds.onmov(evt)}
	override func rightMouseDragged		(with evt: NSEvent) {self.ctrl.binds.onmov(evt)}
	override func otherMouseDragged		(with evt: NSEvent) {self.ctrl.binds.onmov(evt)}
	
}

struct Binds {
	typealias keybinds = [Keystroke : ()->()]
	typealias ptrbinds = [Int : (float2)->()]
	
	var keydn: keybinds = [:]
	var keyup: keybinds = [:]
	var btndn: ptrbinds = [:]
	var btnup: ptrbinds = [:]
	var mov: ptrbinds = [:]
	
	func onkeydn(_ evt: NSEvent) {Self.onkey(evt, binds: self.keydn)}
	func onkeyup(_ evt: NSEvent) {Self.onkey(evt, binds: self.keyup)}
	func onbtndn(_ evt: NSEvent) {Self.onbtn(evt, binds: self.btndn)}
	func onbtnup(_ evt: NSEvent) {Self.onbtn(evt, binds: self.btnup)}
	func onmov(_ evt: NSEvent) {Self.onmov(evt, binds: self.mov)}
	
	private static func onkey(_ evt: NSEvent, binds: keybinds) {
		guard !evt.isARepeat else {return}
		guard let key = Keystroke(rawValue: evt.keyCode) else {return}
		binds[key]?()
	}
	private static func onbtn(_ evt: NSEvent, binds: ptrbinds) {
		let btn = evt.buttonNumber
		let loc = float2(float(evt.locationInWindow.x), float(evt.locationInWindow.y))
		binds[btn]?(loc)
	}
	private static func onmov(_ evt: NSEvent, binds: ptrbinds) {
		let btn = (NSEvent.pressedMouseButtons > 0) ? evt.buttonNumber : -1
		let mov = float2(float(evt.deltaX), float(evt.deltaY))
		binds[btn]?(mov)
	}
	
	enum Keystroke: UInt16, CaseIterable {
		
		case a = 0
		case s = 1
		case d = 2
		case f = 3
		case h = 4
		case g = 5
		case z = 6
		case x = 7
		case c = 8
		case v = 9
		case b = 11
		case q = 12
		case w = 13
		case e = 14
		case r = 15
		case y = 16
		case t = 17
		case o = 31
		case u = 32
		case i = 34
		case p = 35
		case k = 40
		case n = 45
		case m = 46
		
		case _1 = 18
		case _2 = 19
		case _3 = 20
		case _4 = 21
		case _6 = 22
		case _5 = 23
		case _9 = 25
		case _7 = 26
		case _8 = 28
		case _0 = 29
		
		case eql = 24
		case min = 27
		case ent = 36
		case tab = 48
		case del = 51
		case esc = 53
		case spc = 49
		
		case lt = 123
		case rt = 124
		case dn = 125
		case up = 126
		
	}
	
}
