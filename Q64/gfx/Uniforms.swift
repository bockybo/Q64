import MetalKit


struct SVTX {
	var lgt: float4x4 = .idt
	var cam: float4x4 = .idt
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setVertexBytes(&self, length: util.sizeof(self), index: 2)
	}
}

struct SFRG {
	var eyepos: float3 = float3(0)
	var lgtpos: float3 = float3(0)
	var lgthue: float3 = float3(0)
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBytes(&self, length: util.sizeof(self), index: 2)
	}
}

struct MVTX {
	var ctm: float4x4 = .idt
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setVertexBytes(&self, length: util.sizeof(self), index: 1)
	}
}
	
struct MFRG {
	var ambi: float3 = float3(0)
	var diff: float3 = float3(0)
	var spec: float3 = float3(0)
	var shine: float = 0
	mutating func render(enc: MTLRenderCommandEncoder) {
		enc.setFragmentBytes(&self, length: util.sizeof(self), index: 1)
	}
}
