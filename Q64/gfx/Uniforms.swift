import MetalKit


struct CAM {
	var proj: float4x4 = .I
	var view: float4x4 = .I
	var invproj: float4x4 = .I
	var invview: float4x4 = .I
	var res: uint2 = uint2(1)
}

struct LGT {
	var proj: float4x4 = .I
	var view: float4x4 = .I
	var invproj: float4x4 = .I
	var invview: float4x4 = .I
	var hue: float3 = float3(1)
	var phi: float = float(0)
}

struct MDL {
	var ctm:  float4x4 = .I {didSet {self.ctm3 = self.ctm.inv.T.xyz}}
	var ctm3: float3x3 = .I
	var matID: uint
	init(matID: uint, ctm: float4x4 = .I) {
		self.matID = matID
		defer {self.ctm = ctm}
	}
}

struct MAT {
	var alb: float3
	var nml: float3
	var rgh: float
	var mtl: float
	var  ao: float
}

