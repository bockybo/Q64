import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 50
	static let nsph = 0
	static let nhem = 0
	
	static let materials = [
		Material(
			alb: util.texture(path: "snow_alb.jpg", srgb: true),
			nml: util.texture(path: "snow_nml.jpg"),
			rgh: util.texture(path: "snow_rgh.jpg")
		),
		Material(
			alb: util.texture(path: "gold_alb.jpg", srgb: true),
			nml: util.texture(path: "gold_nml.jpg"),
			rgh: util.texture(path: "gold_rgh.jpg"),
			mtl_default: 1.0
		),
		Material(
			alb: util.texture(path: "steel_alb.png", srgb: true),
			nml: util.texture(path: "steel_nml.png"),
			mtl: util.texture(path: "steel_mtl.png"),
			rgh_default: 0.3
		),
		Material(
			alb_default: float3(1, 1, 0)
		),
		Material(
			alb: util.texture(path: "ice_alb.png", srgb: true),
			nml: util.texture(path: "ice_nml.png"),
			rgh_default: 0.1,
			mtl_default: 0.9
		),
		Material(
			alb: util.texture(path: "brick_alb.jpg", srgb: true),
			nml: util.texture(path: "brick_nml.jpg"),
			rgh_default: 0.8
		),
		Material(alb_default: normalize(.xy)),
		Material(alb_default: normalize(.xz)),
		Material(alb_default: normalize(.yz)),
		Material(
			rgh_default: 0.1,
			mtl_default: 1.0
		),
		
		Material(rgh_default: 0.9, mtl_default: 0.0),
		Material(rgh_default: 0.1, mtl_default: 0.0),
		Material(rgh_default: 0.1, mtl_default: 1.0),
		
	]
	
	let crs = Model(meshes: util.mesh.load("cruiser.obj", ctm: .mag(0.25)), [
		Instance(matID: 10)
	])
	let gnd = Model(meshes: [util.mesh.box(dim: Demo.dim * .xz + .y)], [
		Instance(matID: 0, ctm: .ypos(-0.5))
	])
	let ogn = Model(meshes: [util.mesh.sph(dim: 0.4 * (.xz + .y * 2))], [
		Instance(matID: 1)
	])
	let tmp = Model(meshes: util.mesh.load("Temple.obj", ctm: .mag(0.008)), [
		Instance(matID: 2, ctm: .pos(float3(0, 0.01, -5)))
	])
	let sun = Model(meshes: [util.mesh.sph(dim: float3(1.2),
										   seg: uint2(100),
										   inwd: true)], [
		Instance(matID: 3)
	])
	let sph = Model(meshes: [util.mesh.hem(dim: float3(0.5, 6.0, 0.5),
										   seg: uint2(100, 20))],
		.init(repeating: Instance(matID: 4), count: Demo.nsph)
	)
	let hem = Model(meshes: [util.mesh.cap(dim: float3(1.0, 2.5, 1.0),
										   seg: uint3(20, 20, 10))],
		.init(repeating: Instance(matID: 5), count: Demo.nhem)
	)
	let pil = Model(meshes: [util.mesh.cap(dim: float3(0.3, 0.8, 0.3),
										   seg: uint3(20, 20, 20),
										   ctm: .xrot(.pi/2))],
		(0..<Demo.nsph).map {i in Instance(matID: 6 + i%3)}
	)
	let box = Model(meshes: [util.mesh.box(dim: float3(32, 8, 3))], [
		Instance(matID: 9, ctm: .ypos(-0.5) * .zpos(-16)),
		Instance(matID: 9, ctm: .ypos(-0.5) * .xpos(-16) * .yrot(.pi/2)),
		Instance(matID: 9, ctm: .ypos(-0.5) * .xpos(+16) * .yrot(.pi/2)),
	])
	
	
	required init(scene: Scene) {
		defer {self.paused = false}
		
		scene.add([
			self.crs,
			self.gnd,
			self.ogn,
			self.tmp,
//			self.sun,
			self.sph,
			self.hem,
			self.pil,
			self.box,
		])
		
		scene.camera.fov = 60 * .pi/180
		
//		scene.sun.hue = float3(0)
		scene.sun.hue = float3(1)
//		scene.sun.hue = 0.4 * normalize(float3(0.95, 0.85, 0.65))
		scene.sun.dir = -float3(1, 0.5, 1) * Demo.dim
		
		scene.sun.w = Demo.dim / 1.5
		scene.sun.z0 = 0.1
		scene.sun.z1 = Demo.dim
		
		scene.ilights += [
			.init(hue: float3(1, 1, 0), rad: 24),
			.init(hue: float3(1, 0, 1), rad: 24),
			.init(hue: float3(0, 1, 1), rad: 24),
		]
//		scene.ilights.append(.init(hue: float3(100), rad: 10))
		
		for i in 0..<self.sph.nid {
			let a = 2 * .pi * float(i)/float(self.sph.nid)
			let x = 0.25 * Demo.dim * cosf(a)
			let z = 0.25 * Demo.dim * sinf(a)
			let h = float.random(in: 0.6..<1.5)
			let y = 6*h
			let pos = float3(x, 0, z)
			self.sph[i].ctm = .ymag(h) * .pos(pos)
			scene.clights.append(.init(
				hue: 5.0 * Demo.materials[pil[i].matID].alb_default,
				pos: pos + .y * (y + 2),
				rad: 3 * y,
				phi: 25 * .pi/180
			))
		}
		
		for i in 0..<self.hem.nid {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			self.hem[i].ctm = .pos(float3(x, 0, z))
			scene.ilights.append(.init(
				hue: float3(1),
				pos: float3(x, 4, z),
				rad: 5
			))
		}
		
	}
	
	var t: float = 0
	func tick(scene: Scene, ms: float) {
		guard !self.paused else {return}
		self.t += 3e-4 * ms
		
		self.cruiser.tick(dt: ms * 0.2)
		self.camera.tick(dt: ms * 0.2)
		
		scene.camera.pos = self.camera.pos
		scene.camera.rot = self.camera.rot
		
//		scene.sun.dir = -float3(
//			cosf(self.t/2) * Demo.dim,
//			sinf(self.t*2) * 10 + 30,
//			sinf(self.t/2) * Demo.dim
//		)
		
		for i in 0..<3 {
			let a = 2 * .pi * float(i)/float(3)
			let x = 2.4 * cosf(a + self.t)
			let z = 2.4 * sinf(a + self.t)
			scene.ilights[i].pos = self.cruiser.pos + float3(x, 1.5, z)
		}
//		scene.ilights[0].pos = self.cruiser.pos + float3(0, 0.5, 0)
		
		for i in 0..<self.pil.nid {
			let pos = scene.clights[i].pos
			let dir = self.cruiser.pos - pos
			scene.clights[i].dir = dir
			self.pil[i].ctm = .pos(pos) * .direct(dir) * .zpos(3)
		}
		
		self.crs[0].ctm = self.cruiser.ctm
		self.ogn[0].ctm = .yrot(3 * self.t) * .ypos(3)
//		self.sun[0].ctm = .pos(scene.sun.pos)
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 1.5, 0))
	var camera = Camera(pos: float3(0, 10, 15), rot: 30 * .pi/180 * .x)
	
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
		mutating func tick(dt: float) {
			if self.coast {
				self.vel += 0.05 * self.dlt
				self.pos += 0.20 * self.vel * dt
				self.vel *= float3(0.95, 0.9, 0.95)
			} else {
				self.pos += 0.10 * self.dlt * dt
				self.vel = float3(0)
			}
		}
		private var dlt: float3 {
			guard any(self.mov) else {return float3(0)}
			return .yrot(self.rot.y) * normalize(self.mov)
		}
	}
	
	struct Cruiser {
		static let yhov: float = 2
		var mov = float3(0)
		var pos = float3(0)
		var rot = float3(0)
		var vel = float3(0)
		var ctm: float4x4 {
			var ctm = float4x4.pos(self.pos)
			ctm *= .yrot(self.rot.y)
			ctm *= .xrot(self.rot.x)
			ctm *= .zrot(self.rot.z)
			return ctm
		}
		mutating func tick(dt: float) {
			self.vel.y += 0.85 * self.mov.y
			self.vel.y -= 0.10 * (self.pos.y - Self.yhov)
			self.rot.x -= 0.03 * self.mov.x
			self.rot.z -= 0.06 * self.mov.z
			self.rot.y -= 0.08 * self.rot.z * dt
			self.vel.x -= 0.2 * self.rot.x * sin(-self.rot.y)
			self.vel.z -= 0.2 * self.rot.x * cos(-self.rot.y)
			self.pos += 0.018 * self.vel * dt
			self.vel.y *= 0.925
			self.vel.xz *= 0.995
			self.rot.xz *= 0.9
		}
	}
	
	var paused = false {didSet {
		if self.paused {
			CGDisplayShowCursor(CGMainDisplayID())
			CGAssociateMouseAndMouseCursorPosition(1)
		} else {
			CGDisplayHideCursor(CGMainDisplayID())
			CGAssociateMouseAndMouseCursorPosition(0)
		}
	}}
	lazy var binds = Binds(
		keydn: [
			
			.esc: {self.paused = !self.paused},
			.tab: {self.camera.coast = !self.camera.coast},
			
			._1: {self.crs[0].matID = 10},
			._2: {self.crs[0].matID = 11},
			._3: {self.crs[0].matID = 12},
			
			.spc:	{self.camera.mov += .y},
			.f:		{self.camera.mov -= .y},
			.w:		{self.camera.mov -= .z},
			.s:		{self.camera.mov += .z},
			.a:		{self.camera.mov -= .x},
			.d:		{self.camera.mov += .x},
			.up:	{self.cruiser.mov += .x},
			.dn:	{self.cruiser.mov -= .x},
			.lt:	{self.cruiser.mov -= .z},
			.rt:	{self.cruiser.mov += .z},
			.ent:	{self.cruiser.mov += .y},
			
		],
		
		keyup: [
			.spc:	{self.camera.mov -= .y},
			.f:		{self.camera.mov += .y},
			.w:		{self.camera.mov += .z},
			.s:		{self.camera.mov -= .z},
			.a:		{self.camera.mov += .x},
			.d:		{self.camera.mov -= .x},
			.up:	{self.cruiser.mov -= .x},
			.dn:	{self.cruiser.mov += .x},
			.lt:	{self.cruiser.mov += .z},
			.rt:	{self.cruiser.mov -= .z},
			.ent:	{self.cruiser.mov -= .y},
		],
		
		mov: [
			-1: {if !self.paused {self.camera.rot(sns: $0)}}
		]
		
	)
	
}

