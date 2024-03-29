import MetalKit


struct Material {
	static var nproperty = 4
	
	var alb: MTLTexture? = nil
	var nml: MTLTexture? = nil
	var rgh: MTLTexture? = nil
	var mtl: MTLTexture? = nil
	var textures: [MTLTexture?] {
		return [
			self.alb,
			self.nml,
			self.rgh,
			self.mtl
		]
	}
	
	var alb_default = float3(1.0, 1.0, 1.0)
	var nml_default = float3(0.5, 0.5, 1.0)
	var rgh_default: float = 1
	var mtl_default: float = 0
	var defaults: xmaterial {return .init(
		alb: self.alb_default,
		nml: self.nml_default,
		rgh: self.rgh_default,
		mtl: self.mtl_default
	)}
	
}
