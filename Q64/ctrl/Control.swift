import MetalKit


protocol Ctrl {
	var scene: Scene {get}
	var binds: Binds {get}
	func tick()
}
