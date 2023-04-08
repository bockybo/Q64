import MetalKit


struct Camera {
	
	var res: uint2 = uint2(1)
	var fov: float = 75 * .pi/180
	var z0: float = 0.1
	var z1: float = 1e2
	
	var pos = float3(0)
	var rot = float3(0)
	
	var cam: xcamera {
		let proj = float4x4.persp(
			z0: self.z0,
			z1: self.z1,
			fov: self.fov,
			asp: float(self.res.x)/float(self.res.y)
		)
		var view = float4x4.pos(self.pos)
		view *= .zrot(self.rot.z)
		view *= .yrot(self.rot.y)
		view *= .xrot(self.rot.x)
		
		return xcamera(
			proj: proj,
			view: view,
			invproj: proj.inv,
			invview: view.inv,
			z0: self.z0,
			z1: self.z1,
			res: self.res
		)
	}
	
}
