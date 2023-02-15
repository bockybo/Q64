import MetalKit


struct SVTX {
	var cam: float4x4 = .idt
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setVertexBytes(&self, length: sizeof(self), index: 2)
	}
}

struct SFRG {
	var lgtctm: float4x4 = .idt
	var lgtdir: float3 = float3(0)
	var lgthue: float3 = float3(1)
	var eyepos: float3 = float3(0)
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBytes(&self, length: sizeof(self), index: 2)
	}
}

struct MVTX {
	var ctm: float4x4 = .idt
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setVertexBytes(&self, length: sizeof(self), index: 1)
	}
}
	
struct MFRG {
	var ambi: float3 = float3(0)
	var diff: float3 = float3(1)
	var spec: float3 = float3(0)
	var shine: float = 1
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBytes(&self, length: sizeof(self), index: 1)
	}
}
