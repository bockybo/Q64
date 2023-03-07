import MetalKit


protocol Ctrl {
	var binds: Binds {get}
	func tick(scene: Scene, dt: float)
}
