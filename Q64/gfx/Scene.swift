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
	}
	
	struct Unif {
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
	var mdls: [Model]
	var cam = Camera()
	init(_ mdls: [Model] = []) {
		self.mdls = mdls
	}
	
	let uniforms: lib.Buffer<Model.Unif> = {
		let unifs = lib.Buffer<Model.Unif>.init(128)
		for i in 0..<unifs.count {unifs[i] = .init()}
		return unifs
	}()
	
	let lights: lib.Buffer<Sun.Unif> = {
		let lights = lib.Buffer<Sun.Unif>.init(32)
		for i in 1..<lights.count {
			lights[i].rad = 100
			lights[i].hue = [
				float3(1, 1, 1),
				float3(1, 1, 0),
				float3(1, 0, 1),
				float3(0, 1, 1),
			].randomElement()!
			let x = float.random(in: -150..<150)
			let y = float.random(in: -150..<150)
			lights[i].pos = float3(x, 25, y)
		}
		return lights
	}()
	// (tmp.) TODO: unify w/ pt buf & org
	var sun = Sun() {didSet {self.lights[0] = self.sun.unif}}
	
	
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
		
		var p0 = float3(-400, -400, 0.1)
		var p1 = float3(+400, +400, 1e10)
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
