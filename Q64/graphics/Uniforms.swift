import MetalKit


struct SVtx {
	var ctm: m4f
}
struct SFrg {
	var cam: v3f
	var nlt: Int
}

struct MVtx {
	var ctm: m4f
	var hue: v4f
}
struct MFrg {
	var diff: f32
	var spec: f32
	var shine: f32
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
	let texture: MTLTexture?
	var diff: f32
	var spec: f32
	var shine: f32
	
	init(path: String? = nil, diff: f32 = 1, spec: f32 = 0, shine: f32 = 1) {
		self.diff = diff
		self.spec = spec
		self.shine = shine
		if let url = util.url(path) {
			let loader = MTKTextureLoader(device: lib.device)
			self.texture = try! loader.newTexture(
				URL: url,
				options: nil
			)
		} else {
			self.texture = nil
		}
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var mfrg = MFrg(
			diff: self.diff,
			spec: self.spec,
			shine: self.shine)
		enc.setFragmentBytes(&mfrg, length: util.sizeof(MFrg.self), index: 1)
		if let texture = self.texture {
			enc.setFragmentTexture(texture, index: 0)
			enc.setFragmentSamplerState(lib.sstate, index: 0)
			enc.setRenderPipelineState(lib.rstate_text)
		} else {
			enc.setRenderPipelineState(lib.rstate_main)
		}
	}
	
}
