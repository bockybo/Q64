import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 100
	static let nsph = 12
	static let nbox = 36
	
	init(scene: Scene) {
		self.hidecursor()
		
		var crs = Model(
			meshes: util.mesh.load("cruiser.obj", ctm: .mag(0.5))
		)
		var gnd = Model(
			meshes: [util.mesh.box(dim: float3(Demo.dim, 2, Demo.dim), ctm: .ypos(-1))],
			material: Material(
				alb: util.tex.load("snow_alb.jpg", srgb: true),
				nml: util.tex.load("snow_nml.jpg"),
				rgh: util.tex.load("snow_rgh.jpg")
		))
		var ogn = Model(
			meshes: [util.mesh.sph(dim: 0.6 * (.xz + .y * 2), ctm: .ypos(5))],
			material: Material(
				alb: util.tex.load("gold_alb.jpg", srgb: true),
				nml: util.tex.load("gold_nml.jpg"),
				rgh: util.tex.load("gold_rgh.jpg"),
				ao: util.tex.load("gold_ao.jpg"),
				mtl_default: 1.0
		))
		var sun = Model(
			meshes: [util.mesh.sph(dim: float3(2.5), seg: uint2(100), inwd: true)],
			material: Material(
				alb_default: float3(255, 255, 0)
		))
		var sph = Model(
			meshes: [util.mesh.hem(dim: float3(1, 12, 1), seg: uint2(100, 20))],
			material: Material(
				alb: util.tex.load("ice_alb.png", srgb: true),
				nml: util.tex.load("ice_nml.png"),
				mtl: util.tex.load("ice_ao.png"),
				ao: util.tex.load("ice_mtl.png"),
				rgh_default: 0.1
		))
		var box = Model(
			meshes: [util.mesh.cap(dim: float3(2, 5, 2), seg: uint3(20, 20, 10))],
			material: Material(
				alb: util.tex.load("brick_alb.jpg", srgb: true),
				nml: util.tex.load("brick_nml.jpg"),
				rgh_default: 0.1,
				mtl_default: 1.0
		))
		
		crs.add(MDL())
		gnd.add(MDL())
		ogn.add(MDL())
		sun.add(MDL())
		
		scene.lighting.sun.hue = 0.8 * normalize(float3(0.95, 0.85, 0.65))
		scene.lighting.sun.src = float3(1, 0.5, 1) * Demo.dim
		scene.lighting.sun.dst = float3(0)
		scene.lighting.sun.p0.xy = Demo.dim/1.5 * float2(-1)
		scene.lighting.sun.p1.xy = Demo.dim/1.5 * float2(+1)
		
		let hues = [.xy, .xz, .yz].map(normalize)
		
		for _ in 0..<Demo.nsph {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			let h = float.random(in: 0.4..<1.2)
			let y = 12*h
			let pos = float3(x, 0, z)
			sph.add(MDL(ctm: .pos(pos) * .ymag(h)))
			scene.lighting.add_cone(
				hue: 3.2 * hues.randomElement()!,
				src: pos + .y * (y + 6),
				rad: 3 * y,
				phi: 15 * .pi/180
			)
			scene.lighting.add_icos(
				hue: 1.5 * normalize(float3(1)),
				src: pos + .y * (y + 1),
				rad: 0.8 * y + 1
			)
		}
		
		for _ in 0..<Demo.nbox {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			box.add(MDL(ctm: .pos(float3(x, 0, z))))
			scene.lighting.add_icos(
				hue: 1.2 * hues.randomElement()!,
				src: float3(x, 4.0, z),
				rad: 9.0
			)
		}
		
		scene.add([crs, gnd, ogn, sun, sph, box])
		
	}
	
	var t: float = 0
	func tick(scene: Scene, dt: float) {
		guard !self.paused else {return}
		self.t += 0.0016
		
		self.cruiser.tick(dt: dt * 15e-8)
		
		self.camera.tick(dt: dt * 15e-8)
		scene.camera.pos = self.camera.pos
		scene.camera.rot = self.camera.rot
		
		scene.lighting.sun.src = Demo.dim * float3(
			cosf(self.t / 2),
			sinf(self.t * 4) * 0.3 + 0.6,
			sinf(self.t / 2)
		)
		for i in scene.lighting.cone.indices {
//			scene.lighting.cone[i].dst = 3 * .y
			scene.lighting.cone[i].dst = self.cruiser.pos
//			scene.lighting.cone[i].dst = self.camera.pos * .xz
		}
		
		scene[0][0].ctm = self.cruiser.ctm
		scene[2][0].ctm = .yrot(-2 * self.t)
		scene[3][0].ctm = .pos(scene.lighting.sun.src) * .yrot(-self.t * 8)
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 3, 0))
	var camera = Camera(pos: float3(0, 20, 30))
	
	struct Camera {
		var mov = float3(0)
		var pos = float3(0)
		var vel = float3(0)
		var rot = float3(0)
		var coast = true
		mutating func rot(sns: float2) {
			self.rot.x += sns.y * 8e-3
			self.rot.y += sns.x * 8e-3
			self.rot.x = max(min(self.rot.x, +0.5 * .pi), -0.5 * .pi)
		}
		mutating func tick(dt: float)  {
			if self.coast {
				self.vel += 0.1 * dt * self.dlt
				self.pos += 0.2 * dt * self.vel
				self.vel *= float3(0.9, 0.8, 0.9)
			} else {
				self.pos += 0.1 * dt * self.dlt
				self.vel = float3(0)
			}
		}
		private var dlt: float3 {
			if self.mov == float3(0) {return float3(0)}
			return .yrot(self.rot.y) * normalize(self.mov)
		}
	}
	
	struct Cruiser {
		var mov = float3(0)
		var pos = float3(0)
		var rot = float3(0)
		var vel = float3(0)
		mutating func tick(dt: float) {
			self.rot.x -= 0.03 * self.mov.x
			self.rot.z -= 0.08 * self.mov.z
			self.rot.y -= 0.08 * self.rot.z * dt
			self.vel.x += 0.3 * self.rot.x * sin(-self.rot.y)
			self.vel.z += 0.3 * self.rot.x * cos(-self.rot.y)
			self.pos -= 0.03 * self.vel * dt
			self.vel *= 0.997
			self.rot.x *= 0.9
			self.rot.z *= 0.9
		}
		var ctm: float4x4 {
			var ctm = float4x4.pos(self.pos)
			ctm *= .yrot(self.rot.y)
			ctm *= .xrot(self.rot.x)
			ctm *= .zrot(self.rot.z)
			return ctm
		}
	}
	
	var paused = false {didSet {
		self.paused ? self.showcursor() : self.hidecursor()
	}}
	func showcursor() {
		CGDisplayShowCursor(CGMainDisplayID())
		CGAssociateMouseAndMouseCursorPosition(1)
	}
	func hidecursor() {
		CGDisplayHideCursor(CGMainDisplayID())
		CGAssociateMouseAndMouseCursorPosition(0)
	}
	lazy var binds = Binds(
		keydn: [
			.esc: {self.paused = !self.paused},
			.tab: {self.camera.coast = !self.camera.coast},
			.spc:	{self.camera.mov += .y},
			.f:		{self.camera.mov -= .y},
			.w:		{self.camera.mov -= .z},
			.s:		{self.camera.mov += .z},
			.a:		{self.camera.mov -= .x},
			.d:		{self.camera.mov += .x},
			.up:	{self.cruiser.mov += .x},
			.dn:	{self.cruiser.mov -= .x},
			.lt:	{self.cruiser.mov -= .z},
			.rt:	{self.cruiser.mov += .z},
		],
		keyup: [
			.spc:	{self.camera.mov -= .y},
			.f:		{self.camera.mov += .y},
			.w:		{self.camera.mov += .z},
			.s:		{self.camera.mov -= .z},
			.a:		{self.camera.mov += .x},
			.d:		{self.camera.mov -= .x},
			.up:	{self.cruiser.mov -= .x},
			.dn:	{self.cruiser.mov += .x},
			.lt:	{self.cruiser.mov += .z},
			.rt:	{self.cruiser.mov -= .z},
		],
		mov: [
			-1: {if !self.paused {self.camera.rot(sns: $0)}}
		]
	)
	
}

