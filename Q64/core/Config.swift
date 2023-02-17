import MetalKit


class cfg {
	
	static let win_w = 800
	static let win_h = 800
	
	static let tps = 120.0
	static let fps = 144
	
	static let fov: float = 75 * .pi/180
	static let z0: float = 0.1
	static let z1: float = 1e4
	
	static let shdqlt: uint = 16384
	
	static let color_fmt: MTLPixelFormat = .bgra8Unorm
	static let depth_fmt: MTLPixelFormat = .depth32Float
	static let gbuf_fmts: [Int : MTLPixelFormat] = [
		-1: cfg.depth_fmt,	// dep
		 0: cfg.color_fmt,	// rgb: alb, a: material id
		 1: .rgba8Snorm,	// rgb: nml, a: shd
		 2: .rgba8Snorm,	// rgb: eye, a: undef
	]
	
}
