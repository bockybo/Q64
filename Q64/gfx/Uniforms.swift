import MetalKit


struct LFRG {
	var hue: float3
	var dir: float3
	var rad: float
}

struct MVTX {
	var imf: uint
	var ctm: float4x4
}
	
struct MFRG {
	var ambi: float3
	var diff: float3
	var spec: float3
	var shine: float
}
