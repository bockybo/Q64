import MetalKit


class Scene {
	var lgt = Lighting()
	var cam = Camera()
	var models: [Model] = []
	
	func light(enc: MTLRenderCommandEncoder) {
		var svtx = SVTX(cam: self.cam.proj * self.cam.view.inverse)
		var sfrg = SFRG(
			lgtctm: self.lgt.proj * self.lgt.view.inverse,
//			lgtdir: self.lgt.src,
			lgtdir: self.lgt.dst - self.lgt.src,
			lgthue: self.lgt.hue,
			eyepos: self.cam.pos
		)
		svtx.render(enc: enc)
		sfrg.render(enc: enc)
		for model in self.models {
			model.draw(enc: enc, material: true)
		}
	}
	func shade(enc: MTLRenderCommandEncoder) {
		var svtx = SVTX(cam: self.lgt.proj * self.lgt.view.inverse)
		svtx.render(enc: enc)
		for model in self.models {
			model.draw(enc: enc, material: false)
		}
	}
	
	
	struct Camera {
		
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
		
		var hue = float3(1)
		
//		var fov: float = 90 * .pi/180
//		var proj: float4x4 {
//			return .proj(
//				fov: self.fov,
//				aspect: 1,
//				z0: 10,
//				z1: 1e10
//			)
//		}
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
