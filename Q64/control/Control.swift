import MetalKit


protocol Ctrl {
	var scene: Scene {get}
	var binds: Keybinds {get}
	var paused: Bool {get}
	init(device: MTLDevice)
	func tick(dt: f32)
}
