import MetalKit


protocol Entity {
	
	mutating func tick(dt: f32)
	
	var ctm: m4f {get}
	var hue: v4f {get}
	
}
