import MetalKit


// TODO: separate once client/server set up
//	subview to push hooks -> server doesn't need unifs
//	subview to pull unifs <- server doesn't need hooks
class Demo: Ctrl {
	static let dim: float = 50
	static let nsph = 16
	static let nbox = 24
	
	static let materials = [
		Material(),
		Material(
			alb: util.texture(path: "snow_alb.jpg", srgb: true),
			nml: util.texture(path: "snow_nml.jpg"),
			rgh: util.texture(path: "snow_rgh.jpg")
		),
		Material(
			alb: util.texture(path: "gold_alb.jpg", srgb: true),
			nml: util.texture(path: "gold_nml.jpg"),
			rgh: util.texture(path: "gold_rgh.jpg"),
			ao: util.texture(path: "gold_ao.jpg"),
			mtl_default: 1.0
		),
		Material(
			alb_default: float3(255, 255, 0)
		),
		Material(
			alb: util.texture(path: "ice_alb.png", srgb: true),
			nml: util.texture(path: "ice_nml.png"),
			mtl: util.texture(path: "ice_ao.png"),
			ao: util.texture(path: "ice_mtl.png"),
			rgh_default: 0.15
		),
		Material(
			alb: util.texture(path: "brick_alb.jpg", srgb: true),
			nml: util.texture(path: "brick_nml.jpg"),
			rgh_default: 0.1,
			mtl_default: 1.0
		),
		Material(alb_default: normalize(.xy)),
		Material(alb_default: normalize(.xz)),
		Material(alb_default: normalize(.yz)),
	]
	
	required init(scene: Scene) {
		defer {self.paused = false}
		
		let crs = Model(
			meshes: util.mesh.load("cruiser.obj", ctm: .mag(0.25)),
			instances: [MDL(matID: 0)]
		)
		let gnd = Model(
			meshes: [util.mesh.box(dim: Demo.dim * .xz + .y)],
			instances: [MDL(matID: 1, ctm: .ypos(-0.5))]
		)
		let ogn = Model(
			meshes: [util.mesh.sph(dim: 0.4 * (.xz + .y * 2))],
			instances: [MDL(matID: 2)]
		)
		let sun = Model(
			meshes: [util.mesh.sph(dim: float3(1.2),
								   seg: uint2(100),
								   inwd: true)],
			instances: [MDL(matID: 3)]
		)
		var sph = Model(
			meshes: [util.mesh.hem(dim: float3(0.5, 6.0, 0.5),
								   seg: uint2(100, 20))],
			instances: .init(repeating: MDL(matID: 4), count: Demo.nsph)
		)
		var box = Model(
			meshes: [util.mesh.cap(dim: float3(1.0, 2.5, 1.0),
								   seg: uint3(20, 20, 10))],
			instances: .init(repeating: MDL(matID: 5), count: Demo.nbox)
		)
		let pil = Model(
			meshes: [util.mesh.cap(dim: float3(0.3, 0.8, 0.3),
								   seg: uint3(20, 20, 20),
								   ctm: .xrot(.pi/2))],
			instances: (0..<Demo.nsph).map {i in MDL(matID: 6 + uint(i)%3)}
		)
		
		scene.camera.fov = 60 * .pi/180
		
		scene.lighting.sun.hue = 0.8 * normalize(float3(0.95, 0.85, 0.65))
		scene.lighting.sun.src = float3(1, 0.5, 1) * Demo.dim
		scene.lighting.sun.dst = float3(0)
		scene.lighting.sun.p0.xy = Demo.dim/1.5 * float2(-1)
		scene.lighting.sun.p1.xy = Demo.dim/1.5 * float2(+1)
		
		for i in 0..<sph.nid {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			let h = float.random(in: 0.4..<1.2)
			let y = 6*h
			let pos = float3(x, 0, z)
			let hue = Demo.materials[Int(pil[i].matID)].alb_default
			let cone = Conelight(
				hue: 2.0 * hue,
				src: pos + .y * (y + 3),
				rad: 4.5 * y,
				phi: 15 * .pi/180
			)
			let icos = Icoslight(
				hue: float3(3.0),
				rad: 0.5 * y + 1
			)
			sph[i].ctm = .ymag(h) * .pos(pos)
			scene.lighting.cone.append(cone)
			scene.lighting.icos.append(icos)
		}
		
		for i in 0..<box.nid {
			let x = 0.45 * Demo.dim * float.random(in: -1..<1)
			let z = 0.45 * Demo.dim * float.random(in: -1..<1)
			box[i].ctm = .pos(float3(x, 0, z))
			scene.lighting.icos.append(.init(src: float3(x, 2.0, z), rad: 6.0))
		}
		
		scene.add([crs, gnd, ogn, sun, sph, box, pil])
		
	}
	
	var t: float = 0
	func tick(scene: Scene, ms: float) {
		guard !self.paused else {return}
		self.t += 3e-4 * ms
		
		self.cruiser.tick(dt: ms * 0.2)
		self.camera.tick(dt: ms * 0.2)
		
		scene.camera.pos = self.camera.pos
		scene.camera.rot = self.camera.rot
		
		scene.lighting.sun.src = Demo.dim * float3(
			cosf(self.t / 2),
			sinf(self.t * 3) * 0.2 + 0.5,
			sinf(self.t / 2)
		)
		
		for (i, light) in scene.lighting.cone.enumerated() {
			scene.lighting.cone[i].dst = self.cruiser.pos
			scene.lighting.icos[i].src = light.src
			scene[6][i].ctm = .look(src: light.src, dst: self.cruiser.pos) * .zpos(3)
		}
		
		scene[0][0].ctm = self.cruiser.ctm
		scene[2][0].ctm = .yrot(3 * self.t) * .ypos(3)
		scene[3][0].ctm = .pos(scene.lighting.sun.src)
		
	}
	
	
	var cruiser = Cruiser(pos: float3(0, 1.5, 0))
	var camera = Camera(pos: float3(0, 10, 15))
	
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
			return (self.mov == float3(0)) ? float3(0) : .yrot(self.rot.y) * normalize(self.mov)
		}
	}
	
	struct Cruiser {
		var mov = float3(0)
		var pos = float3(0)
		var rot = float3(0)
		var vel = float3(0)
		mutating func tick(dt: float) {
			self.rot.x -= 0.03 * self.mov.x
			self.rot.z -= 0.06 * self.mov.z
			self.rot.y -= 0.08 * self.rot.z * dt
			self.vel.x += 0.2 * self.rot.x * sin(-self.rot.y)
			self.vel.z += 0.2 * self.rot.x * cos(-self.rot.y)
			self.pos -= 0.018 * self.vel * dt
			self.vel *= 0.995
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
		],
		mov: [
			-1: {if !self.paused {self.camera.rot(sns: $0)}}
		]
	)
	
}

