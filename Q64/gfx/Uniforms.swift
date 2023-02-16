import MetalKit


struct SVTX {
	var cam: float4x4 = .idt
	func render(enc: MTLRenderCommandEncoder) {
		var svtx = self
		enc.setVertexBytes(&svtx, length: sizeof(svtx), index: 2)
	}
}

struct SFRG {
	var lgtctm: float4x4 = .idt
	var lgtdir: float3 = float3(0)
	var lgthue: float3 = float3(1)
	var eyepos: float3 = float3(0)
	func render(enc: MTLRenderCommandEncoder) {
		var sfrg = self
		enc.setFragmentBytes(&sfrg, length: sizeof(sfrg), index: 2)
	}
}

struct MVTX {
	var ctm: float4x4 = .idt
	func render(enc: MTLRenderCommandEncoder) {
		var mvtx = self
		enc.setVertexBytes(&mvtx, length: sizeof(mvtx), index: 1)
	}
}
	
struct MFRG {
	var ambi: float = 0
	var diff: float = 1
	var spec: float = 0
	var shine: float = 1
	func render(enc: MTLRenderCommandEncoder) {
		var mfrg = self
		enc.setFragmentBytes(&mfrg, length: sizeof(mfrg), index: 1)
	}
}
