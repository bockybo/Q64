import Foundation


class CtrlClock {
	var time: UInt64
	var timer: Timer!
	
	init(ctrl: Ctrl, tps: Double) {
		self.time = DispatchTime.now().uptimeNanoseconds
		self.timer = Timer(timeInterval: 1/tps, repeats: true) {
			_ in self.tick(ctrl: ctrl)
		}
	}
	deinit {
		self.timer.invalidate()
	}
	
	func run() {
		RunLoop.main.add(self.timer, forMode: .default)
	}
	
	func tick(ctrl: Ctrl) {
		let t0 = self.time
		let t1 = DispatchTime.now().uptimeNanoseconds
		self.time = t1
		if ctrl.paused {return}
		ctrl.tick(dt: f32(t1 - t0) * 1e-6)
	}
	
}
