import MetalKit


struct LFRG {
	var hue: float3
	var dir: float3
	var rad: float
}

struct MDL {
	var ctm: float4x4
	var color: float3
	var shine: float // + == achromatic, - == chromatic
}
