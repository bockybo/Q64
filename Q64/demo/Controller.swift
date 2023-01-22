import MetalKit


class Controller {
	var scene: Scene
	var world: [Entity] = []
	var binds = Keybinds()
	
	var cruiser = Cruiser()
	var paused = false
	var cammov = v3f(0, 0, 0)
	var camvel = v3f(0, 0, 0)
	
	init(device: MTLDevice) {
		
		let bulbmesh = Mesh.sphere(device, seg: 10, type: .line)
		let gndmesh = Mesh.box(device, seg: 1)
		let cruisermeshes	= Mesh.load(device, path: "cruiser", type: .triangle)
		
		let hues = [
			v3f(1, 1, 1),
//			v3f(1, 1, 0),
//			v3f(0, 1, 1),
//			v3f(1, 0, 1),
		]
		
		let ybulb = 120
		let nbulb = 2
		let dim = 2000
		
		self.scene = Scene(device, nlight: 64)
		
		let bulbs = Instances(mesh: bulbmesh)
		self.scene.add(bulbs)
		for x in -nbulb...nbulb {
			for z in -nbulb...nbulb {
				let pos = v3f(
					f32(x * dim / (2*nbulb + 1)),
					f32(ybulb),
					f32(z * dim / (2*nbulb + 1))
				)
				let hue = hues[Int.random(in: 0..<hues.count)]
				let light = Light(pos: pos, hue: hue, amp: 15e3)
				self.scene.lights.add(light)
				let bulbmodel = Model()
				bulbmodel.ctm = m4f.pos(pos) * m4f.mag(2)
				bulbmodel.add(bulbmesh)
				bulbs.add(bulbmodel)
			}
		}
		
		let gndmodel = Model()
		gndmodel.add(gndmesh)
		self.scene.add(gndmodel)
		
		let cruisermodel = Model(ett: self.cruiser)
		cruisermodel.add(cruisermeshes)
		self.scene.add(cruisermodel)
		self.world.append(self.cruiser)
		
		gndmodel.ctm = m4f.mag(v3f(f32(dim), 5, f32(dim)))
		gndmodel.mat.diff = 0.5
		
		cruisermodel.mat.hue = 0.5 * v3f(0, 1, 1)
		cruisermodel.mat.diff = 1.2
		cruisermodel.mat.spec = 1.0
		cruisermodel.mat.shine = 18
		cruisermodel.ctm = m4f.mag(15)
		
		self.scene.pos.y = 30
		self.scene.pos.x = -50
		self.scene.rot.y = -0.5 * .pi
		
		cruiser.pos.y = 20
		
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
	
	func run() {
		_ = CtrlClock(ctrl: self)
	}
	
	func tick(dt: f32) {
		if self.paused {return}
		self.camtick(dt: dt)
		for i in self.world.indices {
			self.world[i].tick(dt: dt)
		}
	}
	
	func camtick(dt: f32) {
		
		let delta = Cursor.delta
		self.scene.rot.x -= 9e-4 * dt * delta.y
		self.scene.rot.y -= 9e-4 * dt * delta.x
		
		self.scene.rot.x = min(self.scene.rot.x, +0.5 * .pi)
		self.scene.rot.x = max(self.scene.rot.x, -0.5 * .pi)
		
		if length_squared(self.cammov) > 0 {
			let mov = normalize(self.cammov) * dt * 3e-2
			self.camvel += mov * m4f.yrot(-self.scene.rot.y)
		}
		self.scene.pos += self.camvel
		self.camvel *= 0.92
		
	}
	
}
