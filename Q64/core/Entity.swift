import MetalKit


protocol Entity {
	
	mutating func tick(dt: f32)
	
	var ctm: m4f {get}
	
}

class CTMEntity: Entity {
	var ctm: m4f
	init(_ ctm: m4f = .idt) {self.ctm = ctm}
	func tick(dt: f32) {}
}
