import MetalKit


struct SVTX {
	var cam: float4x4
	var lgt: float4x4
	var eye: float3
}

struct SFRG {
	var lgtdir: float3
	var lgthue: float3
}

struct MVTX {
	var id: uint
	var ctm: float4x4
}
	
struct MFRG {
	var ambi: float3
	var diff: float3
	var spec: float3
	var shine: float
}
