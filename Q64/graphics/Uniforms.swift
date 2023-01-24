import MetalKit


struct SVtx {
	var proj: m4f
	var view: m4f
}
struct MVtx {
	var ctm: m4f
	var hue: v4f
}
struct MFrg {
	var diff: f32 = 1
	var spec: f32 = 0
	var shine: f32 = 1
}


class Instance {
	var ctm: m4f
	var hue: v4f
	init(ctm: m4f = .idt, hue: v4f = v4f(1, 1, 1, 1)) {
		self.ctm = ctm
		self.hue = hue
	}
	var mvtx: MVtx {
		return MVtx(
			ctm: self.ctm,
			hue: self.hue)
	}
}
class Joint: Instance {
	var ett: Entity
	init(ett: Entity, ctm: m4f = .idt, hue: v4f = v4f(1, 1, 1, 1)) {
		self.ett = ett
		super.init(ctm: ctm, hue: hue)
	}
	override var mvtx: MVtx {
		return MVtx(
			ctm: self.ett.ctm * self.ctm,
			hue: self.ett.hue * self.hue)
	}
}

class Material: Renderable {
	let tex: MTLTexture
	var frg: MFrg
	
	static let texwhite = Material.texload(path: "white.png")
	static func texload(path: String) -> MTLTexture {
		let ldr = MTKTextureLoader(device: lib.device)
		let url = util.url(path)!
		return try! ldr.newTexture(URL: url, options: nil)
	}
	
	init(_ tex: MTLTexture = Material.texwhite, frg: MFrg = MFrg()) {
		self.tex = tex
		self.frg = frg
	}
	convenience init(path: String, frg: MFrg = MFrg()) {
		self.init(Material.texload(path: path), frg: frg)
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBytes(&self.frg, length: util.sizeof(self.frg), index: 1)
		enc.setFragmentTexture(self.tex, index: 0)
	}
	
}
