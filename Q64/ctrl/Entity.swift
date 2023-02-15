import MetalKit


protocol Entity {
	
	mutating func tick()
	
	var uniform: MVTX {get}
	
}
