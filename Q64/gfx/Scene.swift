import MetalKit


struct MDL {
	var ids: Range<Int>
	var meshes: [MTKMesh] = []
	var tex: MTLTexture? = nil
	var prim: MTLPrimitiveType = .triangle
}

class Scene {
	let mvtcs: lib.Buffer<MVTX>
	let mfrgs: lib.Buffer<MFRG>
	var mdls: [MDL]
	var cam = Camera()
	var lgt = Light()
	init(
		nmvtcs: Int = 512,
		nmfrgs: Int = 64,
		mdls: [MDL] = []
	) {
		self.mvtcs = .init(nmvtcs)
		self.mfrgs = .init(nmfrgs)
		self.mdls = mdls
	}
	
	var svtx: SVTX {return SVTX(
		cam: self.cam.ctm,
		lgt: self.lgt.ctm,
		eye: self.cam.pos
	)}
	var sfrg: SFRG {return SFRG(
		lgtdir: self.lgt.dir,
		lgthue: self.lgt.hue
	)}
	
	
	struct Camera {
		var pos = float3(0)
		var rot = float3(0)
		var mag = float3(1)
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
		var view: float4x4 {
			var view = float4x4.pos(self.pos) * .mag(self.mag)
			view *= .zrot(self.rot.z)
			view *= .yrot(self.rot.y)
			view *= .xrot(self.rot.x)
			return view
		}
		var ctm: float4x4 {return self.proj * self.view.inverse}
	}
	
	struct Light {
		static let proj: float4x4 = .orth(
			p0: float3(-200, -200, 0),
			p1: float3(+200, +200, 1e10))
		let view: float4x4
		var hue: float3
		init(src: float3 = float3(0), dst: float3 = float3(0), hue: float3 = float3(1)) {
			self.view = .look(dst: dst, src: src)
			self.hue = hue
		}
		var ctm: float4x4 {return Light.proj * self.view.inverse}
		var src: float3 {return  self.view[3].xyz}
		var dir: float3 {return -normalize(self.view[2].xyz)}
	}
	
}
