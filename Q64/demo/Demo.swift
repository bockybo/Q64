import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 300
	static let nsph = 18
	static let nbox = 25
	
	static var models = [
		Model( // CRUISER
			meshes: lib.meshes("cruiser.obj", ctm: .mag(1.2)),
			material: .init(
				alb: lib.texture("alum_alb.png", srgb: true),
				rgh: lib.texture("alum_rgh.png"),
				mtl: lib.texture("alum_mtl.png"),
				ao: lib.texture("alum_ao.png")
			)
		),
		Model( // GND
			meshes: [meshlib.box(dim: float3(Demo.dim, 10, Demo.dim))],
			material: .init(
				alb: lib.texture("snow_alb.jpg", srgb: true),
				nml: lib.texture("snow_nml.jpg"),
				rgh: lib.texture("snow_rgh.jpg"),
				mtl: lib.texture("snow_mtl.jpg")
			)
		),
		Model( // OGN
			meshes: [meshlib.sph(dim: float3(2, 6, 2)/1.5)],
			material: .init(
				alb: lib.texture("gold_alb.jpg", srgb: true),
				nml: lib.texture("gold_nml.jpg"),
				rgh: lib.texture("gold_rgh.jpg"),
				mtl: lib.texture(src: uchar(255), fmt: .r8Unorm),
				ao: lib.texture("gold_ao.jpg"),
				emm: lib.texture(src: uchar(255), fmt: .r8Unorm)
			)
		),
		Model( // SUN
			meshes: [meshlib.sph(dim: float3(10), seg: uint2(20), inwd: true)],
			material: .init(
				alb: lib.texture(src: uchar4(255, 255, 0, 255), fmt: .rgba8Unorm_srgb)
			),
			prim: .line
		),
		Model( // SPH
			meshes: [meshlib.hem(dim: float3(0.4), seg: uint2(400, 100))],
			material: .init(
				alb: lib.texture("conc_alb.jpg", srgb: true),
				nml: lib.texture("conc_nml.jpg"),
				rgh: lib.texture("conc_rgh.jpg"),
				ao: lib.texture("conc_ao.jpg")
			),
			nid: Demo.nsph
		),
		Model( // BOX
			meshes: [meshlib.box()],
			material: .init(
				alb: lib.texture("brick_alb.jpg", srgb: true),
				nml: lib.texture("brick_nml.jpg"),
				rgh: lib.texture(src: uchar( 64), fmt: .r8Unorm),
				mtl: lib.texture(src: uchar(255), fmt: .r8Unorm)
			),
			nid: Demo.nbox
		),
	]
	
	let scene: Scene = {
		let scene = Scene(Demo.models)
		
		let nins = 4 + Demo.nsph + Demo.nbox
		scene.mdls += [Model.MDL](repeating: .init(ctm: .idt), count: nins)
		scene.lgts += [scene.sun.lgt]
		scene.lgts += (0..<nins).map {_ in .init(
			hue: normalize([
				float3(1, 1, 0),
				float3(1, 0, 1),
				float3(0, 1, 1),
			].randomElement()!)
		)}
		
		scene.sun.hue = 4 * normalize(float3(0.95, 0.85, 0.65))
		scene.sun.dst = float3(0)
		scene.sun.src = float3(1, 0.5, 1) * Demo.dim
		
		for i in 4..<nins {
			let r = float3.random(in: -1..<1) * Demo.dim * 0.45
			var pos = float3(r.x, 5, r.z)
			var mag = float3(6)
			
			if i < 4+Demo.nsph {
				mag.y = abs(r.y)
				
				scene.lgts[i - 3].pos.y = 0.7 * mag.y
				scene.lgts[i - 3].hue *= 10.0
				scene.lgts[i - 3].spr = 15 * .pi/180
				scene.lgts[i - 3].rad = 2.0
				
			} else {
				pos.y += mag.y * 0.5
				
				scene.lgts[i - 3].pos.y = mag.y + 12
				scene.lgts[i - 3].hue *= 3.0
				scene.lgts[i - 3].rad = 1.5
			}
			
			scene.mdls[i].ctm = .pos(pos) * .mag(mag)
			
			scene.lgts[i - 3].pos.x = pos.x
			scene.lgts[i - 3].pos.z = pos.z
			scene.lgts[i - 3].rad *= scene.lgts[i - 3].pos.y
			
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
		self.scene.mdls[0].ctm = .pos(.y * 2) * self.cruiser.ctm
		
		self.camera.tick(dt: dt * 15e-8)
		self.scene.cam.pos = self.camera.pos
		self.scene.cam.rot = self.camera.rot
		
		self.scene.sun.src = 0.75 * Demo.dim * float3(
			cosf(self.t / 2),
			sinf(self.t * 5) * 0.15 + 0.5,
			sinf(self.t / 2)
		)
		
		self.scene.mdls[2].ctm = .yrot(-2 * self.t) * .pos(.y * 20)
		self.scene.mdls[3].ctm = .pos(self.scene.sun.src) * .yrot(-self.t * 8)
		
		for (i, lgt) in self.scene.lgts.enumerated() {
			if lgt.spr != 0 {
				self.scene.lgts[i].dir = normalize(lgt.pos - self.cruiser.pos)
			}
		}
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 12, 0))
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
			self.pos += self.vel * dt
			self.vel *= float3(0.87, 0.8, 0.87)
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
			self.pos -= 0.1 * self.vel * dt
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
	
	
	var timer: Timer!
	var binds = Binds()
	var paused = false
	init() {
		
		Cursor.visible = false
		self.binds.key[.esc] = (dn: {
			self.paused = !self.paused
			Cursor.visible = self.paused
		}, up: {})
		
		self.binds.ptr[-1] = {
			sns in
			if !self.paused {self.camera.rot(sns: sns)}
		}
		
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

