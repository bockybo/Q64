import Foundation


class CtrlClock {
	var time: UInt64
	var timer: Timer!
	
	init(ctrl: Controller) {
		self.time = DispatchTime.now().uptimeNanoseconds
		self.timer = Timer(timeInterval: 1/Config.freq, repeats: true) {
			_ in self.tick(ctrl: ctrl)
		}
	}
	deinit {
		self.timer.invalidate()
	}
	
	func run() {
		RunLoop.main.add(self.timer, forMode: .default)
	}
	
	func tick(ctrl: Controller) {
		let t0 = self.time
		let t1 = DispatchTime.now().uptimeNanoseconds
		self.time = t1
		ctrl.tick(dt: f32(t1 - t0) * 1e-6)
	}
	
}
