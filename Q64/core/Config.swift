import MetalKit


class Config {
	
	static let win_w = 800
	static let win_h = 800
	
	static let color_fmt: MTLPixelFormat = .bgra8Unorm
	static let depth_fmt: MTLPixelFormat = .depth32Float
	
	static let vtxfn = "vtx_main"
	static let frgfn = "frg_main"
	
	static let fov: f32 = 75 * .pi/180
	static let z0: f32 = 0.1
	static let z1: f32 = 2000
	
	static let freq = 120.0
	
}
