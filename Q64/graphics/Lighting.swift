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
	
	let shdmap: MTLTexture = {
		let dim = Int(powf(2, 14))
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: Config.depth_fmt,
			width:  dim,
			height: dim,
			mipmapped: false
		)
		descr.storageMode = .private
		descr.usage = [.renderTarget, .shaderRead]
		return lib.device.makeTexture(descriptor: descr)!
	}()
	
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
