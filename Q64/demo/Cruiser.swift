import MetalKit


class Cruiser: Entity {
	
	var pos = v3f(0, 0, 0)
	var rot = v3f(0, 0, 0)
	
	var vel = v3f(0, 0, 0)
	
	var xmov: f32 = 0
	var zmov: f32 = 0
	
	func tick(dt: f32) {
		
		self.rot.x += 0.006 * dt * self.xmov
		self.rot.z += 0.006 * dt * self.zmov
		
		self.rot.y -= 0.04 * self.rot.z / max(0.3, length(self.vel))
		
		self.vel.x += 0.08 * self.rot.x * sin(self.rot.y)
		self.vel.z += 0.08 * self.rot.x * cos(self.rot.y)
		
		self.pos += self.vel
		self.vel *= 0.992
		self.rot.x *= 0.9
		self.rot.z *= 0.95
		
	}
	
	var ctm: m4f {
		var ctm = m4f.pos(self.pos)
		ctm *= m4f.yrot(self.rot.y)
		ctm *= m4f.xrot(self.rot.x)
		ctm *= m4f.zrot(self.rot.z)
		return ctm
	}
	
}
