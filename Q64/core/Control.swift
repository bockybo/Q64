import MetalKit


protocol Ctrl {
	
	static var materials: [Material] {get}
	init(scene: Scene)
	var binds: Binds {get}
	func tick(scene: Scene, ms: float)
	
}
