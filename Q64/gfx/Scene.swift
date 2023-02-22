import MetalKit


struct MDL {
	var iid: Int
	var nid: Int
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
	
	let lfrgs: lib.Buffer<LFRG> = {
		let lfrgs = lib.Buffer<LFRG>.init(8)
		lfrgs[0].hue = float3(1, 1, 1)
		lfrgs[0].dir = float3(0, 10, 0)
		lfrgs[0].rad = 20
		return lfrgs
	}()
	
	
	struct Camera {
		var pos = float3(0)
		var rot = float3(0)
		var mag = float3(1)
		var asp: float = 1
		var fov: float = 90 * .pi/180
		var z0: float = 1
		var z1: float = 1e3
		var proj: float4x4 {
			return .persp(
				fov: self.fov,
				asp: self.asp,
				z0: self.z0,
				z1: self.z1
			)
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
		var hue = float3(1)
		var src = float3(0)
		var dst = float3(0)
		var p0 = float3(-200, -200, 0)
		var p1 = float3(+200, +200, 1e10)
		var dir: float3 {return normalize(self.dst - self.src)}
		var proj: float4x4 {return .ortho(p0: self.p0, p1: self.p1)}
		var view: float4x4 {return .look(dst: self.dst, src: self.src)}
		var ctm: float4x4 {return self.proj * self.view.inverse}
		var lfrg: LFRG {
			return LFRG(
				hue:  self.hue,
				dir: -self.dir,
				rad: 0
			)
		}
	}
	
}
