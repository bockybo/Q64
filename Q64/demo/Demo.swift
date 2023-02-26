import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 400
	static let nsph = 20
	static let nbox = 30
	
	static let mdls = [
		Model( // CRUISER
			meshes: lib.meshes(path: "cruiser.obj"),
			material: .init(
//				alb: lib.texture(path: "steel_alb.jpg"),
				alb: lib.texture(src: float4(0, 1, 1, 1), fmt: .rgba32Float),
				rgh: lib.texture(src: float(0.1), fmt: .r32Float),
				mtl: lib.texture(src: float(0.0), fmt: .r32Float)
			)
			 ),
		Model( // GND
			meshes: [meshlib.box(dim: float3(Demo.dim, 10, Demo.dim))],
			material: .init(
//				alb: lib.texture(path: "dirt_alb.png"),
				nml: lib.texture(path: "dirt_nml.png"),
				rgh: lib.texture(path: "dirt_rgh.png")
			)
			 ),
		Model( // OGN
			meshes: [meshlib.sph(dim: float3(4, 11, 4))],
			material: .init(
				alb: lib.texture(src: float4(1, 0, 1, 1), fmt: .rgba32Float),
				rgh: lib.texture(src: float(0.1), fmt: .r32Float),
				mtl: lib.texture(src: float(0.0), fmt: .r32Float)
			)
			 ),
		Model( // SUN
			meshes: [meshlib.sph(dim: float3(10), seg: uint2(20), inwd: true)],
			material: .init(
				alb: lib.texture(src: float4(1, 1, 0, 1), fmt: .rgba32Float)
			),
			prim: .line
			 ),
		Model( // SPH
			meshes: [meshlib.sph(seg: uint2(100, 10))],
			material: .init(
				rgh: lib.texture(src: float(0.2), fmt: .r32Float),
				mtl: lib.texture(src: float(1.0), fmt: .r32Float)
			),
			nid: Demo.nsph
			 ),
		Model( // BOX
			meshes: [meshlib.box()],
			material: .init(
				alb: lib.texture(path: "brick_alb.jpg"),
				nml: lib.texture(path: "brick_nml.jpg"),
				rgh: lib.texture(src: float(0.2), fmt: .r32Float),
				mtl: lib.texture(src: float(1.0), fmt: .r32Float)
			),
			nid: Demo.nbox
			 ),
	]
	
	let scene: Scene = {
		let scene = Scene(Demo.mdls)
		
		scene.sun.hue = 5 * normalize(float3(0.95, 0.85, 0.65))
		scene.sun.dst = float3(0)
		scene.sun.src = float3(1, 0.5, 1) * Demo.dim
		
		for i in 4 ..< 4+Demo.nsph+Demo.nbox {
			let r = float3.random(in: -1..<1) * Demo.dim * 0.45
			var pos = float3(r.x, 0, r.z)
			var mag = float3(6)
			if i < 4+Demo.nsph {
				mag.y = abs(r.y)
				mag *= 0.4
			} else {
				pos.y += 5 + mag.y/2
			}
			scene.uniforms[i].ctm = .pos(pos) * .mag(mag)
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
		self.scene.uniforms[0].ctm = self.cruiser.ctm * .mag(1.5)
		
		self.camera.tick(dt: dt * 15e-8)
		self.scene.cam.pos = self.camera.pos
		self.scene.cam.rot = self.camera.rot
		
		self.scene.sun.src = Demo.dim * float3(
			cosf(self.t),
			sinf(self.t * 10) * 0.2 + 0.5,
			sinf(self.t)
		)
		
		self.scene.uniforms[2].ctm = .yrot(-self.t)
		self.scene.uniforms[3].ctm = .pos(self.scene.sun.src) * .yrot(-self.t * 8)
		
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
		
		self.timer = Timer(timeInterval: 1/cfg.tps, repeats: true) {_ in self.tick()}
		RunLoop.main.add(self.timer, forMode: .default)
		
	}
	
	deinit {
		self.timer.invalidate()
		self.timer = nil
	}
	
}

