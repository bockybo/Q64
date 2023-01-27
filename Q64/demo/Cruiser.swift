import MetalKit


class Cruiser: Entity {
	
	var pos = v3f(0, 0, 0)
	var rot = v3f(0, 0, 0)
	
	var vel = v3f(0, 0, 0)
	
	var xmov: f32 = 0
	var zmov: f32 = 0
	
	func tick(dt: f32) {
		
		self.rot.x += 0.003 * dt * self.xmov
		self.rot.z += 0.008 * dt * self.zmov
		
		self.rot.y -= 0.05 * self.rot.z / max(0.4, length(self.vel))
		
		self.vel.x += 0.02 * self.rot.x * sin(self.rot.y)
		self.vel.z += 0.02 * self.rot.x * cos(self.rot.y)
		
		self.pos += 0.9 * self.vel
		self.vel *= 0.997
		self.rot.x *= 0.9
		self.rot.z *= 0.9
		
	}
	
	var ctm: m4f {
		var ctm = m4f.pos(self.pos)
		ctm *= m4f.yrot(self.rot.y)
		ctm *= m4f.xrot(self.rot.x)
		ctm *= m4f.zrot(self.rot.z)
		return ctm
	}
	
}
