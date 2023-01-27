import MetalKit


class Material {
	let tex: MTLTexture
	var ambi: f32 = 0
	var diff: f32 = 1
	var spec: f32 = 0
	var shine: f32 = 1
	
	init(_ tex: MTLTexture) {
		self.tex = tex
	}
	
	convenience init(path: String) {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = util.url(path)!
		let tex = try! ldr.newTexture(URL: url, options: nil)
		self.init(tex)
	}
	
	convenience init(hue: v4f = .one) {
		
		let descr = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: Config.color_fmt,
			width:  1,
			height: 1,
			mipmapped: false
		)
		descr.storageMode = .managed
		descr.usage = .shaderRead
		let tex = lib.device.makeTexture(descriptor: descr)!
		
		let b = hue.x, g = hue.y, r = hue.z, a = hue.w
		var hue = simd_uchar4(v4f(r, g, b, a) * 255)
		
		let ogn = MTLOrigin(x: 0, y: 0, z: 0)
		let dim = MTLSize(width: 1, height: 1, depth: 1)
		let rgn = MTLRegion(origin: ogn, size: dim)
		
		tex.replace(region: rgn, mipmapLevel: 0, withBytes: &hue, bytesPerRow: util.sizeof(hue))
		self.init(tex)
		
	}
	
	var mfrg: MFrg {
		return MFrg(
			ambi: self.ambi,
			diff: self.diff,
			spec: self.spec,
			shine: self.shine
		)
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var frg = self.mfrg
		enc.setFragmentBytes(&frg, length: util.sizeof(frg), index: 1)
		enc.setFragmentTexture(self.tex, index: 0)
	}
	
	struct MFrg {
		var ambi: f32
		var diff: f32
		var spec: f32
		var shine: f32
	}
	
}
