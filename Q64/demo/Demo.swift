import MetalKit


class Demo: Ctrl {
	let scene = Scene()
	var binds = Keybinds()
	var paused = false
	
	let crs: Model
	
	let cruiser = Cruiser()
	var cammov = v3f(0, 0, 0)
	var camvel = v3f(0, 0, 0)
	
	init() {
		
		let crspos = v3f(0, 2, 2)
		let sphpos = v3f(0, 4, 3)
		let lgtpos = v3f(0, 9, 0)
		
		let gnd = Model(CTMEntity(m4f.mag(v3f(1000, 0.1, 1000))))
		let sph = Model(CTMEntity(m4f.pos(sphpos) * m4f.mag(0.2)))
		self.crs = Model(self.cruiser)
		
		gnd.material.ambi = 0.5
		gnd.material.diff = 0
		self.crs.material = Material(hue: v4f(0, 1, 1, 1))
//		self.crs.material = Material(path: "steel.jpg")
		self.crs.material.diff = 0.4
		self.crs.material.spec = 0.6
		self.crs.material.shine = 8
		
		gnd.meshes.append(Mesh.plane(seg: 1))
		sph.meshes.append(Mesh.sphere(seg: 10, type: .line))
		self.crs.meshes += Mesh.load(path: "cruiser.obj")
		self.scene.models += [gnd, sph, crs]
		
		self.scene.cam.pos = v3f(0, 4, 10)
		self.scene.cam.rot = v3f(0, 0, 0) * .pi/180
		self.scene.lgt.src = lgtpos
		self.scene.lgt.dst = crspos
		
		self.cruiser.pos = crspos
		
		
		Cursor.hide()
		self.binds.keydn[.esc]	= {
			self.paused = !self.paused
			self.paused ? Cursor.show() : Cursor.hide()
		}
		
		self.binds.keydn[.spc]	= {self.cammov.y += +1}
		self.binds.keyup[.spc]	= {self.cammov.y += -1}
		self.binds.keydn[.f]	= {self.cammov.y -= +1}
		self.binds.keyup[.f]	= {self.cammov.y -= -1}
		self.binds.keydn[.w] 	= {self.cammov.z -= +1}
		self.binds.keyup[.w] 	= {self.cammov.z -= -1}
		self.binds.keydn[.s] 	= {self.cammov.z += +1}
		self.binds.keyup[.s] 	= {self.cammov.z += -1}
		self.binds.keydn[.a] 	= {self.cammov.x -= +1}
		self.binds.keyup[.a] 	= {self.cammov.x -= -1}
		self.binds.keydn[.d] 	= {self.cammov.x += +1}
		self.binds.keyup[.d] 	= {self.cammov.x += -1}
		
		self.binds.keydn[.up] = {self.cruiser.xmov += +1}
		self.binds.keydn[.dn] = {self.cruiser.xmov -= +1}
		self.binds.keydn[.lt] = {self.cruiser.zmov -= +1}
		self.binds.keydn[.rt] = {self.cruiser.zmov += +1}
		self.binds.keyup[.up] = {self.cruiser.xmov += -1}
		self.binds.keyup[.dn] = {self.cruiser.xmov -= -1}
		self.binds.keyup[.lt] = {self.cruiser.zmov -= -1}
		self.binds.keyup[.rt] = {self.cruiser.zmov += -1}
		
	}
	
	func tick(dt: f32) {
		
		let delta = Cursor.delta
		self.scene.cam.rot.x -= 9e-4 * dt * delta.y
		self.scene.cam.rot.y -= 9e-4 * dt * delta.x
		
		self.scene.cam.rot.x = min(self.scene.cam.rot.x, +0.5 * .pi)
		self.scene.cam.rot.x = max(self.scene.cam.rot.x, -0.5 * .pi)
		
		if length_squared(self.cammov) > 0 {
			let mov = normalize(self.cammov) * dt * 3e-3
			self.camvel += mov * m4f.yrot(-self.scene.cam.rot.y)
		}
		self.scene.cam.pos += self.camvel
		self.camvel *= 0.92
		
		self.cruiser.tick(dt: dt)
		
		self.scene.lgt.dst = self.cruiser.pos
		
	}
	
}

