import Cocoa


class Cursor {
	
	class var delta: (x: f32, y: f32) {
		let (x, y) = CGGetLastMouseDelta()
		return (x: f32(x), y: f32(y))
	}
	
	class func hide() {
		CGDisplayHideCursor(CGMainDisplayID())
		CGAssociateMouseAndMouseCursorPosition(0)
	}
	class func show() {
		CGDisplayShowCursor(CGMainDisplayID())
		CGAssociateMouseAndMouseCursorPosition(1)
	}
	
}
