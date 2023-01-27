import MetalKit


struct Lighting {
	
	var hue = v3f(1, 1, 1)
	
	let proj = m4f.orth(
		p0: v3f(-100, -100, 0),
		p1: v3f(+100, +100, +1000))
	
	var src: v3f = .zero
	var dst: v3f = .zero
	var view: m4f {
		return m4f.look(
			dst: self.dst,
			src: self.src
		)
	}
	
	struct LFrg {
		var hue = v3f.one
		var dir = v3f.zero
	}
	var lfrg: LFrg {
		return LFrg(
			hue: self.hue,
			dir: normalize(self.dst - self.src)
		)
	}
	
}
