import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 100
	static let nsph = 12
	static let nbox = 36
	
	let scene: Scene = {
		let scene = Scene([
			Model( // crs: 0
				meshes: lib.mesh.load("cruiser.obj", ctm: .mag(0.5))
			),
			Model( // gnd: 1
				meshes: [lib.mesh.box(dim: float3(Demo.dim, 2, Demo.dim), ctm: .ypos(-1))],
				material: Material(
					alb: lib.tex.load("snow_alb.jpg", srgb: true),
					nml: lib.tex.load("snow_nml.jpg"),
					rgh: lib.tex.load("snow_rgh.jpg")
			)),
			Model( // ogn: 2
				meshes: [lib.mesh.sph(dim: 0.6 * (.xz + .y * 2), ctm: .ypos(5))],
				material: Material(
					alb: lib.tex.load("gold_alb.jpg", srgb: true),
					nml: lib.tex.load("gold_nml.jpg"),
					rgh: lib.tex.load("gold_rgh.jpg"),
					 ao: lib.tex.load("gold_ao.jpg"),
					mtl_default: 1.0
			)),
			Model( // sun: 3
				meshes: [lib.mesh.sph(dim: float3(2.5), seg: uint2(10), inwd: true)],
				material: Material(
					alb_default: float3(255, 255, 0)
			)),
			Model( // sph: 4
				meshes: [lib.mesh.hem(dim: float3(1, 12, 1), seg: uint2(100, 20))],
				material: Material(
					alb: lib.tex.load("ice_alb.png", srgb: true),
					nml: lib.tex.load("ice_nml.png"),
					mtl: lib.tex.load("ice_ao.png"),
					 ao: lib.tex.load("ice_mtl.png"),
					rgh_default: 0.1
			)),
			Model( // box: 5
				meshes: [lib.mesh.caps(dim: float3(2, 5, 2), seg: uint3(20, 20, 10))],
				material: Material(
					alb: lib.tex.load("brick_alb.jpg", srgb: true),
					nml: lib.tex.load("brick_nml.jpg"),
					rgh_default: 0.1,
					mtl_default: 1.0
			)),
		])
		
		scene[0].add(MDL())
		scene[1].add(MDL())
		scene[2].add(MDL())
		scene[3].add(MDL())
		
		scene.lighting.sun.hue = 0.8 * normalize(float3(0.95, 0.85, 0.65))
		scene.lighting.sun.src = float3(1, 0.5, 1) * Demo.dim
		scene.lighting.sun.dst = float3(0)
		scene.lighting.sun.p0.xy = Demo.dim/1.5 * float2(-1)
		scene.lighting.sun.p1.xy = Demo.dim/1.5 * float2(+1)
		
		var hues = [.xy, .xz, .yz].map(normalize)
		
		for _ in 0..<Demo.nsph {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			let h = float.random(in: 0.4..<1.2)
			let y = 12*h
			let pos = float3(x, 0, z)
			scene[4].add(MDL(ctm: .pos(pos) * .ymag(h)))
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
			scene[5].add(MDL(ctm: .pos(float3(x, 0, z))))
			scene.lighting.add_icos(
				hue: 1.2 * hues.randomElement()!,
				src: float3(x, 4.0, z),
				rad: 9.0
			)
		}
		
		return scene
	}()
	
	var t0 = DispatchTime.now().uptimeNanoseconds
	var dt: float? {
		let t1 = DispatchTime.now().uptimeNanoseconds
		let dt = t1 - self.t0
		self.t0 = t1
		if self.paused {return nil}
		return float(dt)
	}
	var t: float = 0
	
	func tick() {
		guard let dt = self.dt else {return}
		self.t += 0.0016
		
		self.cruiser.tick(dt: dt * 15e-8)
		
		self.camera.tick(dt: dt * 15e-8)
		self.scene.camera.pos = self.camera.pos
		self.scene.camera.rot = self.camera.rot
		
		self.scene.lighting.sun.src = Demo.dim * float3(
			cosf(self.t / 2),
			sinf(self.t * 5) * 0.3 + 0.5,
			sinf(self.t / 2)
		)
		for i in self.scene.lighting.cone.indices {
//			self.scene.lighting.cone[i].dst = 3 * .y
			self.scene.lighting.cone[i].dst = self.cruiser.pos
//			self.scene.lighting.cone[i].dst = self.camera.pos * .xz
		}
		
		self.scene[0][0].ctm = self.cruiser.ctm
		self.scene[2][0].ctm = .yrot(-2 * self.t)
		self.scene[3][0].ctm = .pos(self.scene.lighting.sun.src) * .yrot(-self.t * 8)
		
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
	
	
	var paused: Bool {
		get {return Cursor.visible}
		set(paused) {Cursor.visible = paused}
	}
	
	var timer: Timer!
	var binds = Binds()
	init() {
		
		self.paused = false
		self.binds.key[.esc] = (dn: {self.paused = !self.paused}, up: {})
		
		self.binds.ptr[-1] = {if !self.paused {self.camera.rot(sns: $0)}}
		
		self.binds.key[.tab]	= (dn: {self.camera.coast = !self.camera.coast}, up: {})
		
		self.binds.key[.spc]	= (dn: {self.camera.mov += .y}, up: {self.camera.mov -= .y})
		self.binds.key[.f]		= (dn: {self.camera.mov -= .y}, up: {self.camera.mov += .y})
		self.binds.key[.w] 		= (dn: {self.camera.mov -= .z}, up: {self.camera.mov += .z})
		self.binds.key[.s] 		= (dn: {self.camera.mov += .z}, up: {self.camera.mov -= .z})
		self.binds.key[.a] 		= (dn: {self.camera.mov -= .x}, up: {self.camera.mov += .x})
		self.binds.key[.d] 		= (dn: {self.camera.mov += .x}, up: {self.camera.mov -= .x})
		
		self.binds.key[.up] 	= (dn: {self.cruiser.mov += .x}, up: {self.cruiser.mov -= .x})
		self.binds.key[.dn] 	= (dn: {self.cruiser.mov -= .x}, up: {self.cruiser.mov += .x})
		self.binds.key[.lt] 	= (dn: {self.cruiser.mov -= .z}, up: {self.cruiser.mov += .z})
		self.binds.key[.rt] 	= (dn: {self.cruiser.mov += .z}, up: {self.cruiser.mov -= .z})
		
		self.timer = Timer(timeInterval: 1/Double(cfg.tps), repeats: true) {_ in self.tick()}
		RunLoop.main.add(self.timer, forMode: .default)
		
	}
	
	deinit {
		self.timer.invalidate()
		self.timer = nil
	}
	
}

