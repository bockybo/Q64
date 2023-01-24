import MetalKit


struct Light {
	var pos: v3f
	var hue: v3f
	init(pos: v3f, hue: v3f = .one, amp: f32 = 1) {
		self.pos = pos
		self.hue = hue * amp
	}
}

class Lights: Renderable {
	static let maxnlt = 64
	
	let buf: MTLBuffer
	var num = 0
	init() {
		self.buf = lib.device.makeBuffer(
			length: Lights.maxnlt * util.sizeof(Light.self),
			options: [.storageModeShared])!
	}
	
	var ptr: UnsafeMutablePointer<Light> {
		return self.buf.contents().assumingMemoryBound(to: Light.self)
	}
	func add(_ light: Light) {
		self[self.num] = light
		self.num += 1
	}
	subscript(i: Int) -> Light {
		get {return self.ptr[i]}
		set(light) {self.ptr[i] = light}
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBuffer(self.buf, offset: 0, index: 3)
	}
	
}

