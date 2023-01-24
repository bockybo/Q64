import MetalKit


struct Light {
	var pos: v3f
	var hue: v3f
	var amp: f32
	init(pos: v3f, hue: v3f = .one, amp: f32 = 1) {
		self.pos = pos
		self.hue = hue
		self.amp = amp
	}
}

class Lights {
	static let maxnlt = 64
	
	let buf: MTLBuffer
	init() {
		let n = Lights.maxnlt
		self.buf = lib.device.makeBuffer(
			length: n * util.sizeof(Light.self),
			options: [.storageModeShared])!
		for i in 0..<n {
			self[i] = Light(pos: .zero, amp: 0)
		}
	}
	
	var ptr: UnsafeMutablePointer<Light> {
		return self.buf.contents().assumingMemoryBound(to: Light.self)
	}
	subscript(i: Int) -> Light {
		get {return self.ptr[i]}
		set(light) {self.ptr[i] = light}
	}
	
}

