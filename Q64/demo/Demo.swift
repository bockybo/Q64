import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	let scene: Scene = {
		let dim: float = 300
		let nsph = 10
		let nbox = 20
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
		
		let scene = Scene(
			nmvtcs: 512,
			nmfrgs: 8,
			mdls: [
//				MDL(iid: 0, 		nid: 1, 		meshes: lib.meshes(path: "cruiser.obj"), tex: lib.texture(path: "steel.jpg")),
				MDL(iid: 0, 		nid: 1,			meshes: lib.meshes(path: "cruiser.obj")),
				MDL(iid: 1, 		nid: 1, 		meshes: [lib.boxmesh(1)]),
				MDL(iid: 2, 		nid: 1, 		meshes: [lib.mesh(vtcs: ogn_vtcs, idcs: ogn_idcs)]),
				MDL(iid: 3, 		nid: 1, 		meshes: [lib.sphmesh(20, invnml: true)], prim: .line),
				MDL(iid: 4,			nid: nsph, 		meshes: [lib.sphmesh(100)]),
				MDL(iid: 4+nsph, 	nid: nbox, 		meshes: [lib.boxmesh(1)]),
			]
		)
		
		scene.mvtcs[0].imf = 0 // CRS
		scene.mvtcs[1].imf = 1 // GND
		scene.mvtcs[2].imf = 2 // OGN
		scene.mvtcs[3].imf = 3 // SUN
		for i in 0..<scene.mdls[4].nid {scene.mvtcs[i+scene.mdls[4].iid].imf = 4} // SPH -> OBS
		for i in 0..<scene.mdls[5].nid {scene.mvtcs[i+scene.mdls[5].iid].imf = 4} // BOX -> OBS
		
		scene.mvtcs[1].ctm = .mag(float3(dim, 10, dim))
		for i in 4..<4+nobs {
			let r = float3.random(in: -1..<1) * dim * 0.45
			scene.mvtcs[i].ctm = .pos(r * (1 - .y)) * .mag(float3(2.5, abs(r.y * 0.3), 2.5))
		}
		
//		scene.mvtcs[4+nobs-1].ctm = .pos(3 * .x) * .mag(float3(1, 20, 1))
		
		scene.mfrgs[0].ambi = 0.1 * float3(0, 1, 1)
		scene.mfrgs[0].diff = 0.5 * float3(0, 1, 1)
		scene.mfrgs[0].spec = 0.6 * float3(1, 1, 1)
		scene.mfrgs[0].shine = 5
		
		scene.mfrgs[1].ambi = 0.1 * float3(1)
		scene.mfrgs[1].diff = 0.9 * float3(1)
		
		scene.mfrgs[2].diff = 0.6 * float3(1, 0, 1)
		scene.mfrgs[2].spec = 0.5 * float3(1)
		scene.mfrgs[2].shine = 32
		
		scene.mfrgs[3].ambi = 0.1 * float3(1, 1, 0)
		scene.mfrgs[3].diff = 0.9 * float3(1, 1, 0)
		
		scene.mfrgs[4].ambi = 0.1 * float3(1)
		scene.mfrgs[4].diff = 1.0 * float3(1)
		
		return scene
	}()
	
	var time: float = 0
	func tick() {
		if self.paused {return}
		self.time += 0.001
		
		self.cruiser.tick()
		self.camera.tick()
		
		self.scene.cam.pos = self.camera.pos
		self.scene.cam.rot = self.camera.rot
		
		self.scene.lgt.src = 200 * float3(
			cosf(self.time),
			sinf(self.time * 10) * 0.1 + 0.5,
			sinf(self.time)
		)
		
		self.scene.mvtcs[0].ctm = self.cruiser.ctm * .mag(1.2)
		self.scene.mvtcs[2].ctm = .mag(float3(2, 7.5, 2)) * .yrot(self.time * 5)
		self.scene.mvtcs[3].ctm = .pos(self.scene.lgt.src) * .mag(10) * .yrot(self.time * 8)
		
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
		mutating func tick()  {
			if self.mov != .zero {
				let mov = float4x4.pos(normalize(self.mov))
				let rot = float4x4.yrot(self.rot.y)
				let vel = (rot * mov)[3].xyz
				self.vel += vel * 0.1
			}
			self.pos += self.vel
			self.vel *= 0.93
		}
	}
	
	struct Cruiser {
		var mov = float3(0)
		var pos = float3(0)
		var rot = float3(0)
		var vel = float3(0)
		mutating func tick() {
			self.rot.x -= 0.03 * self.mov.x
			self.rot.z -= 0.08 * self.mov.z
			self.rot.y -= 0.1 * self.rot.z
			self.vel.x += 0.2 * self.rot.x * sin(-self.rot.y)
			self.vel.z += 0.2 * self.rot.x * cos(-self.rot.y)
			self.pos -= 0.1 * self.vel
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

