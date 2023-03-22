import Cocoa


class CtrlView: NSView {
	var ctrl: Ctrl!
	
	var running: Bool {return self.timer != nil}
	var nanos: UInt64 {return DispatchTime.now().uptimeNanoseconds}
	var timer: Timer? = nil
	func start(tps: Int, scene: Scene) {
		if self.running {self.stop()}
		var t0 = self.nanos
		self.timer = Timer(timeInterval: 1/Double(tps), repeats: true) {_ in
			t0 = self.tick(t0, scene: scene)
		}
		RunLoop.main.add(self.timer!, forMode: .default)
	}
	func stop() {
		self.timer?.invalidate()
		self.timer = nil
	}
	func tick(_ t0: UInt64, scene: Scene) -> UInt64 {
		let t1 = self.nanos
		let ns = t1 - t0
		self.ctrl.tick(scene: scene, ms: 1e-6 * float(ns))
		return t1
	}
	deinit {
		self.stop()
	}
	
}

extension CtrlView {
	
	override var acceptsFirstResponder: Bool {return true}
	override func acceptsFirstMouse(for evt: NSEvent?) -> Bool {return true}
	
	override func keyDown			(with evt: NSEvent) {Binds.onkey(evt, self.ctrl.binds.keydn)}
	override func keyUp				(with evt: NSEvent) {Binds.onkey(evt, self.ctrl.binds.keyup)}
	
	override func mouseDown			(with evt: NSEvent) {Binds.onkey(evt, self.ctrl.binds.keydn)}
	override func mouseUp			(with evt: NSEvent) {Binds.onbtn(evt, self.ctrl.binds.btnup)}
	override func rightMouseDown	(with evt: NSEvent) {Binds.onbtn(evt, self.ctrl.binds.btndn)}
	override func rightMouseUp		(with evt: NSEvent) {Binds.onbtn(evt, self.ctrl.binds.btnup)}
	override func otherMouseDown	(with evt: NSEvent) {Binds.onbtn(evt, self.ctrl.binds.btndn)}
	override func otherMouseUp		(with evt: NSEvent) {Binds.onbtn(evt, self.ctrl.binds.btnup)}
	
	override func mouseMoved		(with evt: NSEvent) {Binds.onmov(evt, self.ctrl.binds.mov)}
	override func mouseDragged		(with evt: NSEvent) {Binds.onmov(evt, self.ctrl.binds.mov)}
	override func rightMouseDragged	(with evt: NSEvent) {Binds.onmov(evt, self.ctrl.binds.mov)}
	override func otherMouseDragged	(with evt: NSEvent) {Binds.onmov(evt, self.ctrl.binds.mov)}
	
}

struct Binds {
	typealias Keybinds = [Keystroke : ()->()]
	typealias Ptrbinds = [Int : (float2)->()]
	
	var keydn: Keybinds = [:]
	var keyup: Keybinds = [:]
	var btndn: Ptrbinds = [:]
	var btnup: Ptrbinds = [:]
	var mov: Ptrbinds = [:]
	
	fileprivate static func onkey(_ evt: NSEvent, _ binds: Keybinds) {
		guard !evt.isARepeat else {return}
		guard let key = Keystroke(rawValue: evt.keyCode) else {return}
		var mod = evt.modifierFlags.rawValue
		mod &= NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
		mod &= NSEvent.ModifierFlags.command.rawValue
		guard 0 == mod else {return}
		binds[key]?()
	}
	fileprivate static func onbtn(_ evt: NSEvent, _ binds: Ptrbinds) {
		let btn = evt.buttonNumber
		let loc = float2(float(evt.locationInWindow.x), float(evt.locationInWindow.y))
		binds[btn]?(loc)
	}
	fileprivate static func onmov(_ evt: NSEvent, _ binds: Ptrbinds) {
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
