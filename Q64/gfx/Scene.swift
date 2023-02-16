import MetalKit


class Scene {
	var lgt = Lighting()
	var cam = Camera()
	var models: [Model] = []
	
//	func light(enc: MTLRenderCommandEncoder) {
//		var svtx = self.cam.svtx
//		var sfrg = self.sfrg
//		svtx.render(enc: enc)
//		sfrg.render(enc: enc)
//		self.draw(enc: enc, material: true)
//	}
//	func shade(enc: MTLRenderCommandEncoder) {
//		var svtx = self.lgt.svtx
//		svtx.render(enc: enc)
//		self.draw(enc: enc, material: false)
//	}
	
	func draw(enc: MTLRenderCommandEncoder, material: Bool) {
		for model in self.models {
			model.draw(enc: enc, material: material)
		}
	}
	
	var sfrg: SFRG {return SFRG(
		lgtctm: self.lgt.proj * self.lgt.view.inverse,
//		lgtdir: self.lgt.src,
		lgtdir: normalize(self.lgt.src - self.lgt.dst),
		lgthue: self.lgt.hue,
		eyepos: self.cam.pos
	)}
	
	
	struct Camera {
		var svtx: SVTX {return SVTX(cam: self.proj * self.view.inverse)}
		
		var proj: float4x4 = .idt
		var aspect: float = 1 {
			didSet {
				self.proj = .proj(
					fov: cfg.fov,
					aspect: self.aspect,
					z0: cfg.z0,
					z1: cfg.z1
				)
			}
		}
		
		var pos = float3(0)
		var rot = float3(0)
		var mag = float3(1)
		var view: float4x4 {
			var view = float4x4.pos(self.pos) * .mag(self.mag)
			view *= .zrot(self.rot.z)
			view *= .yrot(self.rot.y)
			view *= .xrot(self.rot.x)
			return view
		}
		
	}
	
	struct Lighting {
		var svtx: SVTX {return SVTX(cam: self.proj * self.view.inverse)}
		
		var hue = float3(1)
		
		var proj: float4x4 {
			return .orth(
				p0: float3(-200, -200, 0),
				p1: float3(+200, +200, 1e10)
			)
		}
		
		var view: float4x4 = .look(dst: float3(1), src: float3(0))
		var src = float3(1) {didSet {self.view = .look(dst: self.dst, src: self.src)}}
		var dst = float3(0) {didSet {self.view = .look(dst: self.dst, src: self.src)}}
		
	}
	
}
