import MetalKit


struct Model {
	var meshes: [MTKMesh] = []
	var material = Material()
	var nid = 1
	var prim: MTLPrimitiveType = .triangle
	
	struct Material {
		var alb: MTLTexture? = nil
		var nml: MTLTexture? = nil
		var rgh: MTLTexture? = nil
		var mtl: MTLTexture? = nil
		var  ao: MTLTexture? = nil
		var emm: MTLTexture? = nil
	}
	
	struct MDL {
		var ctm: float4x4 = .idt {didSet {
			let inv = self.ctm.inverse.transpose
			self.inv[0] = inv[0].xyz
			self.inv[1] = inv[1].xyz
			self.inv[2] = inv[2].xyz
		}}
		var inv: float3x3 = .idt
	}
	
}



class Scene {
	var models: [Model]
	init(_ models: [Model] = []) {
		self.models = models
	}
	
	var cam = Camera()
	var sun = Sun() {didSet {self.lgts[0] = self.sun.lgt}}
	
	
	// once ptlgts have shadows, can be refactored; CAM and LGT independent, no SCN
	struct SCN {
		var sun_ctm: float4x4
		var cam_ctm: float4x4
		var cam_inv: float4x4
		var cam_pos: float3
	}
	struct LGT {
		var hue: float3 = float3(1)
		var pos: float3 = float3(0)
		var dir: float3 = float3(0)
		var rad: float = float(0)
		var spr: float = float(0)
	}
	
	var mdls: [Model.MDL] = []
	var lgts: [Scene.LGT] = []
	var scn: SCN {return .init(
		sun_ctm: self.sun.ctm,
		cam_ctm: self.cam.ctm,
		cam_inv: self.cam.inv,
		cam_pos: self.cam.pos
	)}
	
	struct Camera {
		
		var asp: float = 1
		var fov: float = 65 * .pi/180
		var z0: float = 0.1
		var z1: float = 1e3
		var proj: float4x4 {
			return .persp(
				fov: self.fov,
				asp: self.asp,
				z0: self.z0,
				z1: self.z1
			)
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
		
		var ctm: float4x4 {return self.proj * self.view.inverse}
		var inv: float4x4 {return self.view * self.proj.inverse}
		
	}
	
	struct Sun {
		var hue = float3(1)
		var src = float3(0)
		var dst = float3(0)
		var dir: float3 {return normalize(self.dst - self.src)}
		
		var p0 = float3(-225, -225, 0.1)
		var p1 = float3(+225, +225, 1e10)
		var proj: float4x4 {return .ortho(p0: self.p0, p1: self.p1)}
		var view: float4x4 {return .look(dst: self.dst, src: self.src)}
		var ctm: float4x4 {return self.proj * self.view.inverse}
		
		var lgt: Scene.LGT {
			return .init(
				hue:  self.hue,
				dir: -self.dir
			)
		}
		
	}
	
}
