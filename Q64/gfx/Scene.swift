import MetalKit


struct Model {
	var iid: Int
	var nid: Int
	var meshes: [MTKMesh] = []
	var tex: MTLTexture? = nil
	var prim: MTLPrimitiveType = .triangle
	
	struct Unif {
		var ctm: float4x4
		var color: float3
		var rough: float
		var metal: float
	}
	
}

class Scene {
	var mdls: [Model]
	var cam = Camera()
	init(_ mdls: [Model] = []) {
		self.mdls = mdls
	}
	
	let uniforms = lib.Buffer<Model.Unif>(512)
	
	let lfrgs: lib.Buffer<Light.Unif> = {
		let lfrgs = lib.Buffer<Light.Unif>.init(64)
		for i in 1..<64 {
			lfrgs[i].rad = 150
			lfrgs[i].hue = [
				float3(1, 1, 1),
				float3(1, 1, 0),
				float3(1, 0, 1),
				float3(0, 1, 1),
			].randomElement()!
			let x = float.random(in: -150..<150)
			let y = float.random(in: -150..<150)
			lfrgs[i].pos = float3(x, 20, y)
		}
		return lfrgs
	}()
	// (tmp.) TODO: unify w/ pt buf & org
	var lgt = Light() {didSet {self.lfrgs[0] = self.lgt.unif}}
	
	
	struct Camera {
		
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
	
	struct Light {
		var hue = float3(1)
		var src = float3(0)
		var dst = float3(0)
		var dir: float3 {return normalize(self.dst - self.src)}
		
		var p0 = float3(-200, -200, 0)
		var p1 = float3(+200, +200, 1e5)
		var proj: float4x4 {return .ortho(p0: self.p0, p1: self.p1)}
		var view: float4x4 {return .look(dst: self.dst, src: self.src)}
		var ctm: float4x4 {return self.proj * self.view.inverse}
		
		var unif: Unif {
			return .init(
				hue:  self.hue,
				pos: -self.dir,
				rad: 0
			)
		}
		
		struct Unif {
			var hue: float3
			var pos: float3
			var rad: float
		}
		
	}
	
}
