import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	let scene: Scene = {
		let dim: float = 300
		let nsph = 15
		let nbox = 30
		let nobs = nsph + nbox
		
		let ogn_vtcs = [
			float3(-1, 0, -1),
			float3( 0, 0, +1),
			float3(+1, 0, -1),
			float3( 0, 1,  0),
		]
		let ogn_idcs: [uint] = [
			0, 1, 2,
			0, 1, 3,
			1, 2, 3,
			2, 0, 3,
		]
		
		let scene = Scene([
//			Model(iid: 0, 		nid: 1, 	meshes: lib.meshes(path: "cruiser.obj"), tex: lib.texture(path: "steel.jpg")),
			Model(iid: 0, 		nid: 1,		meshes: lib.meshes(path: "cruiser.obj")),
			Model(iid: 1, 		nid: 1, 	meshes: [lib.boxmesh(1)]),
			Model(iid: 2, 		nid: 1, 	meshes: [lib.mesh(vtcs: ogn_vtcs, idcs: ogn_idcs)]),
			Model(iid: 3, 		nid: 1, 	meshes: [lib.sphmesh(20, invnml: true)], prim: .line),
			Model(iid: 4,		nid: nsph, 	meshes: [lib.sphmesh(100)]),
			Model(iid: 4+nsph, 	nid: nbox, 	meshes: [lib.boxmesh(1)]),
		])
		
		scene.lgt.hue = 1.0 * float3(0.95, 0.85, 0.65)
		
		scene.uniforms[0].color = float3(0, 1, 1)
		scene.uniforms[0].rough = 0.5
		scene.uniforms[0].metal = 0.9
		scene.uniforms[1].color = float3(1, 1, 1)
		scene.uniforms[1].rough = 1.0
		scene.uniforms[1].metal = 0.0
		scene.uniforms[2].color = float3(1, 0, 1)
		scene.uniforms[2].rough = 1.0
		scene.uniforms[2].metal = 0.0
		scene.uniforms[3].color = float3(1, 1, 0)
		scene.uniforms[3].rough = 1.0
		scene.uniforms[3].metal = 0.0
		
		scene.uniforms[1].ctm = .mag(float3(dim, 10, dim))
		
		for i in 4..<4+nobs {
			
			let r = float3.random(in: -1..<1) * dim * 0.45
			scene.uniforms[i].ctm = .pos(r * (1 - .y)) * .mag(float3(2.5, 0.4 * abs(r.y), 2.5))
			
			scene.uniforms[i].color = float3(1)
			scene.uniforms[i].rough = 1.0
			scene.uniforms[i].metal = 0.0
			
		}
		
		return scene
	}()
	
	var t0 = DispatchTime.now().uptimeNanoseconds
	var time: float = 0
	func tick() {
		if self.paused {return}
		self.time += 0.0015
		
		let t1 = DispatchTime.now().uptimeNanoseconds
		let dt = 1e-7 * float(t1 - self.t0)
		self.t0 = t1
		
		self.cruiser.tick(dt: dt)
		self.camera.tick(dt: dt)
		
		self.scene.cam.pos = self.camera.pos
		self.scene.cam.rot = self.camera.rot
		
		self.scene.lgt.src = 300 * float3(
			cosf(self.time),
			sinf(self.time * 10) * 0.12 + 0.5,
			sinf(self.time)
		)
		
		self.scene.uniforms[0].ctm = self.cruiser.ctm * .mag(1.5)
		self.scene.uniforms[2].ctm = .mag(float3(2, 7.5, 2)) * .yrot(self.time * 5)
		self.scene.uniforms[3].ctm = .pos(self.scene.lgt.src) * .mag(10) * .yrot(self.time * 8)
		
//		self.scene.lfrgs[0].dir = self.scene.lgt.src
//		self.scene.lfrgs[0].rad = 300
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 8, 0))
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
			self.vel *= 0.9
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
			self.rot.y -= 0.1 * self.rot.z * dt
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

