import MetalKit


class BaseETT: Entity {
	let uniform: MVTX
	init(_ ctm: float4x4 = .idt) {self.uniform = MVTX(ctm: ctm)}
	func tick() {}
}
