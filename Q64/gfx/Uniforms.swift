import MetalKit


struct CAM {
	var proj: float4x4
	var view: float4x4
	var invproj: float4x4
	var invview: float4x4
	var res: uint2
}
struct SCN {
	var nlgt: uint
	var cam: CAM
}

struct LGT {
	var proj: float4x4
	var hue: float3
	var pos: float3
	var dir: float3
	var rad: float
	var phi: float
}

struct MDL {
	var ctm: float4x4
	var inv: float4x4
	var matID: uint
}

struct MAT {
	var alb: float3
	var nml: float3
	var rgh: float
	var mtl: float
	var  ao: float
}
