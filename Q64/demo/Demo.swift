import MetalKit


class Demo: Ctrl {
	var scene: Scene
	var binds = Keybinds()
	var paused = false
	
	var world: [Entity] = []
	var cruiser = Cruiser()
	var cammov = v3f(0, 0, 0)
	var camvel = v3f(0, 0, 0)
	
	required init(device: MTLDevice) {
		
		let hues = [
			v3f(1, 1, 1),
//			v3f(1, 1, 0),
//			v3f(0, 1, 1),
//			v3f(1, 0, 1),
		]
		
		let ybulb = 120
		let nbulb = 2
		let dim = 2000
		
		let bulbmesh = Mesh.sphere(device, seg: 10, type: .triangle)
		var gndmodel = Model(
			meshes: [Mesh.box(device, seg: 1)],
			rstate: lib.rstate_main(device))
		var cruisermodel = Model(
			meshes: Mesh.load(device, path: "cruiser", type: .triangle),
			rstate: lib.rstate_main(device),
			ett: self.cruiser
		)
		
		gndmodel.ctm = m4f.mag(v3f(f32(dim), 5, f32(dim)))
		gndmodel.diff = 0.5
		
		cruisermodel.ctm = m4f.mag(15)
		cruisermodel.hue = 0.5 * v3f(0, 1, 1)
		cruisermodel.diff = 1.2
		cruisermodel.spec = 0.8
		cruisermodel.shine = 12
		
		
		self.scene = Scene(device)
		
		self.scene.pos.y = 50
		self.scene.pos.z = -100
		self.scene.rot.y = .pi
		self.cruiser.rot.y = 0.5 * .pi
		self.cruiser.pos.y = 20
		
		
		var bulbmodels: [Model] = []
		for x in -nbulb...nbulb {
			for z in -nbulb...nbulb {
				let pos = v3f(
					f32(x * dim / (2*nbulb + 1)),
					f32(ybulb),
					f32(z * dim / (2*nbulb + 1))
				)
				let hue = hues[Int.random(in: 0..<hues.count)]
				let light = Light(pos: pos, hue: hue, amp: 15e3)
				var bulbmodel = Model()
				bulbmodel.ctm = m4f.pos(pos) * m4f.mag(2)
				bulbmodel.hue = v3f.random(in: 0..<1)
				bulbmodels.append(bulbmodel)
				self.scene.lights.add(light)
			}
		}
		self.scene.add(Instances(device, mesh: bulbmesh, models: bulbmodels))
		
		self.scene.add(gndmodel)
		self.scene.add(cruisermodel)
		self.world.append(self.cruiser)
		
		
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
		
		for i in self.world.indices {
			self.world[i].tick(dt: dt)
		}
		
	}
	
}
