import MetalKit


protocol Ctrl {
	var scene: Scene {get}
	var binds: Keybinds {get}
	var paused: Bool {get}
	func tick(dt: f32)
}
