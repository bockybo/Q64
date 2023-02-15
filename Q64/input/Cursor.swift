import Cocoa


class Cursor {
	
	class var delta: float2 {
		let (x, y) = CGGetLastMouseDelta()
		return float2(float(x), float(y))
	}
	
	static var visible: Bool = true {
		didSet {
			if Cursor.visible {
				CGDisplayShowCursor(CGMainDisplayID())
				CGAssociateMouseAndMouseCursorPosition(1)
			} else {
				CGDisplayHideCursor(CGMainDisplayID())
				CGAssociateMouseAndMouseCursorPosition(0)
			}
		}
	}
	
}
