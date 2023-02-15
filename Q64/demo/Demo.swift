import MetalKit


class Demo: Ctrl {
	let scene = Scene()
	var binds = Binds()
	
	let cruiser: Cruiser
	var cammov = float3(0)
	var camvel = float3(0)
	
	var models: [Model] = {
		
		let dim: float = 250
		let nbox = 25
		
		var boxes: [BaseETT] = []
		for _ in 0..<nbox {
			let w: float = 3
			let h = float.random(in: 3..<30)
			let loc = float2.random(in: -dim..<dim)
			let pos = float3(loc.x, h, loc.y) * 0.5
			let mag = float3(w, h, w)
			boxes.append(BaseETT(.pos(pos) * .mag(mag)))
		}
		
		return [
			Model(
				[Cruiser()],
				meshes: lib.mesh(path: "cruiser.obj"),
//				texture: lib.texture(path: "steel.jpg"),
				mfrg: MFRG(
					diff: 0.7 * float3(0, 1, 1),
					spec: 0.6 * float3(1, 1, 1),
					shine: 9.0
				)
			),
			Model(
				[BaseETT(.mag(float3(dim, 0.1, dim)))],
				meshes: [lib.boxmesh(1)],
				mfrg: MFRG(
					ambi: 0.1 * float3(0.6, 0.5, 0.5),
					diff: 0.8 * float3(0.6, 0.5, 0.5)
				)
			),
			Model(
				boxes,
				meshes: [lib.sphmesh(100)],
				mfrg: MFRG(
					ambi: 0.2 * float3(1, 1, 1)
				)
			),
			Model(
				[BaseETT(.pos(float3(0, 0, -10)) * .mag(float3(10)))],
				meshes: [lib.mesh(
					vtcs: [
						float3(-1, 0, -1),
						float3( 0, 0, +1),
						float3(+1, 0, -1),
						float3( 0, 1,  0),
					],
					idcs: [
						0, 1, 2,
						0, 1, 3,
						1, 2, 3,
						2, 0, 3,
					]
				)],
				mfrg: MFRG(
					diff: float3(1, 0, 1),
					spec: float3(1, 1, 1),
					shine: 30
				)
			)
		]
	}()
	
	init() {
		
		self.cruiser = self.models[0].entities[0] as! Cruiser
		self.scene.models = self.models
		
		self.scene.cam.pos = float3(0, 10, 30)
		self.scene.cam.rot = float3(0, 0, 0) * .pi/180
		
		self.scene.lgt.hue = float3(1, 1, 1)
		self.scene.lgt.dst = float3(0, 0, 0)
		self.scene.lgt.src = float3(10, 50, 10)
		
		self.cruiser.pos = float3(0, 2, 10)
		
		
		Cursor.visible = false
		self.binds.key[.esc] = (dn: {Cursor.visible = !Cursor.visible}, up: {})
		
		self.binds.ptr[-1] = {mov in
			self.scene.cam.rot.x += mov.y * 8e-3
			self.scene.cam.rot.y += mov.x * 8e-3
			self.scene.cam.rot.x = min(self.scene.cam.rot.x, +0.5 * .pi)
			self.scene.cam.rot.x = max(self.scene.cam.rot.x, -0.5 * .pi)
		}
		
		self.binds.key[.spc]	= (dn: {self.cammov.y += 1}, up: {self.cammov.y -= 1})
		self.binds.key[.f]		= (dn: {self.cammov.y -= 1}, up: {self.cammov.y += 1})
		self.binds.key[.w] 		= (dn: {self.cammov.z -= 1}, up: {self.cammov.z += 1})
		self.binds.key[.s] 		= (dn: {self.cammov.z += 1}, up: {self.cammov.z -= 1})
		self.binds.key[.a] 		= (dn: {self.cammov.x -= 1}, up: {self.cammov.x += 1})
		self.binds.key[.d] 		= (dn: {self.cammov.x += 1}, up: {self.cammov.x -= 1})
		
		self.binds.key[.up] 	= (dn: {self.cruiser.mov.x += 1}, up: {self.cruiser.mov.x -= 1})
		self.binds.key[.dn] 	= (dn: {self.cruiser.mov.x -= 1}, up: {self.cruiser.mov.x += 1})
		self.binds.key[.lt] 	= (dn: {self.cruiser.mov.y -= 1}, up: {self.cruiser.mov.y += 1})
		self.binds.key[.rt] 	= (dn: {self.cruiser.mov.y += 1}, up: {self.cruiser.mov.y -= 1})
		
	}
	
	func tick() {
		
		self.cruiser.tick()
		
		if self.cammov != .zero {
			let mov = float4x4.pos(normalize(self.cammov))
			let rot = float4x4.yrot(self.scene.cam.rot.y)
			self.camvel += (rot * mov)[3].xyz * 0.05
		}
		
		self.scene.cam.pos += self.camvel
		self.camvel *= 0.9
		
	}
	
	
	class Cruiser: Entity {
		
		var pos = float3(0)
		var rot = float3(0)
		var vel = float3(0)
		var mov = float2(0)
		
		func tick() {
			
			self.rot.x += self.mov.x * 0.03
			self.rot.z += self.mov.y * 0.08
			
			self.rot.y -= 0.1 * self.rot.z
			let rot = float2.rot(self.rot.y) * self.rot.x * 0.2
			self.vel.x += rot.y
			self.vel.z += rot.x
			
			self.pos += 0.08 * self.vel
			self.vel *= 0.997
			self.rot.x *= 0.9
			self.rot.z *= 0.9
			
		}
		
		var ctm: float4x4 {
			var ctm = float4x4.pos(self.pos)
			ctm *= .yrot(-self.rot.y)
			ctm *= .xrot(-self.rot.x)
			ctm *= .zrot(-self.rot.z)
			return ctm
		}
		var uniform: MVTX {return MVTX(ctm: self.ctm)}
		
	}
	
}

