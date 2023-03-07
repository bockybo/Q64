import MetalKit


class Scene {
	var lighting = Lighting()
	var models: [Model] = []
	
	func add(_ model: Model) {
		self.models.append(model)
	}
	func add(_ models: [Model]) {
		self.models += models
	}
	subscript(i: Int) -> Model {
		get {return self.models[i]}
		set(model) {self.models[i] = model}
	}
	
	var cam: CAM {return self.camera.cam}
	var mdls: [MDL] {
		var mdls: [MDL] = []
		for model in self.models {
			mdls += model.mdls
		}
		return mdls
	}
	var lgts: [LGT] {
		let quad = self.lighting.quad.map {$0.lgt}
		let cone = self.lighting.cone.map {$0.lgt}
		let icos = self.lighting.icos.map {$0.lgt}
		return quad + cone + icos
	}
	
	
	var camera = Camera()
	struct Camera {
		
		var res: uint2 = uint2(1)
		var fov: float = 75 * .pi/180
		var z0: float = 0.0001
		var z1: float = 1e3
		
		var asp: float {return float(self.res.x)/float(self.res.y)}
		
		var pos = float3(0)
		var rot = float3(0)
		var mag = float3(1)
		
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
		
		var cam: CAM {
			let proj = self.proj
			let view = self.view
			return .init(
				proj: proj,
				view: view,
				invproj: proj.inv,
				invview: view.inv,
				res: self.res
			)
		}
		
	}
	
}
