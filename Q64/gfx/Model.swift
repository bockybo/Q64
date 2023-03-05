import MetalKit


struct Model {
	var meshes: [MTKMesh] = []
	var material: Material = Material()
	
	var mdls: [MDL] = []
	var count: Int {return self.mdls.count}
	subscript(i: Int) -> MDL {
		get {return self.mdls[i]}
		set(mdl) {self.mdls[i] = mdl}
	}
	mutating func add(_ mdl: MDL) {
		self.mdls.append(mdl)
	}
	mutating func add(_ mdls: [MDL]) {
		self.mdls += mdls
	}
	
}

struct Material {
	
	var alb: MTLTexture? = nil
	var nml: MTLTexture? = nil
	var rgh: MTLTexture? = nil
	var mtl: MTLTexture? = nil
	var  ao: MTLTexture? = nil
	var textures: [MTLTexture?] {
		return [
			self.alb,
			self.nml,
			self.rgh,
			self.mtl,
			self.ao
		]
	}
	
	var alb_default = float3(1)
	var rgh_default: float = 1
	var mtl_default: float = 0
	var  ao_default: float = 1
	var defaults: MAT {return .init(
		alb: self.alb_default,
		rgh: self.rgh_default,
		mtl: self.mtl_default,
		ao: self.ao_default
	)}
	
}
