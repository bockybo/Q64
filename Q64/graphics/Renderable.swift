import MetalKit


protocol Renderable {
	func render(enc: MTLRenderCommandEncoder)
}
