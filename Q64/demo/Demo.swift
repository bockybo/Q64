import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 150
	static let nsph = Renderer.nshd
	static let nbox = 2 * Demo.nsph
	
	let models = [
		"crs": Model(
			iid: 0,
			meshes: lib.mesh.load("cruiser.obj", ctm: .mag(0.6)),
			props: .init(
				rgh: lib.tex.load("alum_rgh.png"),
				mtl: lib.tex.load("alum_mtl.png"),
				ao: lib.tex.load("alum_ao.png")
			)),
		"gnd": Model(
			iid: 1,
			mesh: lib.mesh.box(dim: float3(Demo.dim, 5, Demo.dim)),
			props: .init(
				alb: lib.tex.load("snow_alb.jpg", srgb: true),
				nml: lib.tex.load("snow_nml.jpg"),
				rgh: lib.tex.load("snow_rgh.jpg"),
				mtl: lib.tex.load("snow_mtl.jpg")
			)),
		"ogn": Model(
			iid: 2,
			mesh: lib.mesh.sph(dim: float3(0.5, 2.0, 0.5)),
			props: .init(
				alb: lib.tex.load("gold_alb.jpg", srgb: true),
				nml: lib.tex.load("gold_nml.jpg"),
				rgh: lib.tex.load("gold_rgh.jpg"),
				mtl: lib.tex.oxo(uchar(255), fmt: .r8Unorm),
				ao: lib.tex.load("gold_ao.jpg")
			)),
		"sun": Model(
			iid: 3,
			mesh: lib.mesh.sph(dim: float3(5), seg: uint2(10), inwd: true),
			props: .init(
				alb: lib.tex.oxo(uchar4(255, 255, 0, 255), fmt: .rgba8Unorm_srgb)
			)),
		"sph": Model(
			iid: 4,
			nid: Demo.nsph,
			mesh: lib.mesh.hem(dim: float3(1.0), seg: uint2(200, 40)),
			props: .init(
				alb: lib.tex.load("marble_alb.png", srgb: true),
				rgh: lib.tex.load("marble_rgh.png"),
				ao: lib.tex.load("marble_ao.png")
			)),
		"box": Model(
			iid: Demo.nsph + 4,
			nid: Demo.nbox,
			mesh: lib.mesh.box(dim: float3(3.0)),
			props: .init(
				alb: lib.tex.load("brick_alb.jpg", srgb: true),
				nml: lib.tex.load("brick_nml.jpg"),
				rgh: lib.tex.oxo(uchar( 32), fmt: .r8Unorm),
				mtl: lib.tex.oxo(uchar(255), fmt: .r8Unorm)
			)),
	]
	
	lazy var scene: Scene = {
		let scene = Scene(self.models)
		
		scene.mdls += [Scene.MDL](repeating: .init(), count: 4)
		
		scene.sun.hue = 2.5 * normalize(float3(0.95, 0.85, 0.65))
		scene.sun.dst = float3(0)
		scene.sun.src = float3(1, 0.5, 1) * Demo.dim
		scene.sun.p0 = float3(-Demo.dim/1.5, -Demo.dim/1.5, 0.0)
		scene.sun.p1 = float3(+Demo.dim/1.5, +Demo.dim/1.5, 1e4)
		
		var hues = [
			float3(1, 1, 0),
			float3(1, 0, 1),
			float3(0, 1, 1),
		].map(normalize)
		
		for i in scene["sph"]!.ids {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			let h = float.random(in: 1..<24)
			let ymdl: float = 2.5
			let ylgt: float = ymdl + h + 10
			scene.mdls.append(Scene.MDL(.pos(float3(x, ymdl, z)) * .mag(float3(1, h, 1))))
			scene.lights.append(Light(
				hue: 8.0 * hues.randomElement()!,
				src: float3(x, ylgt, z),
				rad: 2.5 * ylgt,
				fov: 20 * .pi/180
			))
		}
		
		for i in scene["box"]!.ids {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			let ymdl: float = 2.5 + 3/2
			let ylgt: float = 1.6 * (2.5 + 3)
			scene.mdls.append(Scene.MDL(.pos(float3(x, ymdl, z))))
			scene.lights.append(Light(
				hue: 2.0 * hues.randomElement()!,
				src: float3(x, ylgt, z),
				rad: 2.0 * ylgt
			))
		}
		
		return scene
	}()
	
	var t0 = DispatchTime.now().uptimeNanoseconds
	var dt: float {
		let t1 = DispatchTime.now().uptimeNanoseconds
		let dt = t1 - self.t0
		self.t0 = t1
		if self.paused {return 0}
		return float(dt)
	}
	var t: float = 0
	
	func tick() {
		let dt = self.dt
		if (dt == 0) {return}
		self.t += 0.0016
		
		self.cruiser.tick(dt: dt * 15e-8)
		
		self.camera.tick(dt: dt * 15e-8)
		self.scene.cam.pos = self.camera.pos
		self.scene.cam.rot = self.camera.rot
		
		self.scene.sun.src = Demo.dim * float3(
			cosf(self.t / 2),
			sinf(self.t * 5) * 0.2 + 0.6,
			sinf(self.t / 2)
		)
		
		self.scene.mdls[self.scene["crs"]!.iid].ctm = self.cruiser.ctm
		self.scene.mdls[self.scene["ogn"]!.iid].ctm = .yrot(-2 * self.t) * .pos(.y * 10)
		self.scene.mdls[self.scene["sun"]!.iid].ctm = .pos(self.scene.sun.src) * .yrot(-self.t * 8)
		
		for (i, light) in self.scene.lights.enumerated() where light.is_spot {
			self.scene.lights[i].dst = self.cruiser.pos
		}
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 7, 0))
	var camera = Camera(pos: float3(0, 20, 30))
	
	struct Camera {
		var mov = float3(0)
		var pos = float3(0)
		var vel = float3(0)
		var rot = float3(0)
		mutating func rot(sns: float2) {
			self.rot.x += sns.y * 8e-3
			self.rot.y += sns.x * 8e-3
			self.rot.x = max(min(self.rot.x, +0.5 * .pi), -0.5 * .pi)
		}
		mutating func tick(dt: float)  {
			if self.mov != .zero {
				let mov = float4x4.pos(normalize(self.mov))
				let rot = float4x4.yrot(self.rot.y)
				let vel = (rot * mov)[3].xyz
				self.vel += vel * 0.1
			}
			self.pos += 0.6 * self.vel * dt
			self.vel *= float3(0.85, 0.75, 0.85)
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
			self.vel.x += 0.2 * self.rot.x * sin(-self.rot.y)
			self.vel.z += 0.2 * self.rot.x * cos(-self.rot.y)
			self.pos -= 0.05 * self.vel * dt
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

