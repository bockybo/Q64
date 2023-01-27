import MetalKit


protocol Model {
	
	func render(enc: MTLRenderCommandEncoder)
	var material: Material {get set}
	
}
