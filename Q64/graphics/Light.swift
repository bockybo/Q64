import MetalKit


struct Light {
	var pos: v3f
	var hue: v3f
	init(pos: v3f, hue: v3f = .one, amp: f32 = 1) {
		self.pos = pos
		self.hue = hue * amp
	}
}
