import Foundation


class CtrlClock {
	var time: UInt64
	init(ctrl: Controller) {
		self.time = DispatchTime.now().uptimeNanoseconds
		let timer = Timer(timeInterval: 1/Config.freq, repeats: true) {
			_ in
			let t0 = self.time
			let t1 = DispatchTime.now().uptimeNanoseconds
			self.time = t1
			ctrl.tick(dt: f32(t1 - t0) * 1e-6)
		}
		RunLoop.main.add(timer, forMode: .default)
	}
}
