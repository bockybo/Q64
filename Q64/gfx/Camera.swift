import MetalKit


struct Camera {
	
	var res: uint2 = uint2(1)
	var fov: float = 75 * .pi/180
	var z0: float = 1e-4
	var z1: float = 1e3
	
	var asp: float {return float(self.res.x)/float(self.res.y)}
	
	var pos = float3(0)
	var rot = float3(0)
	var mag = float3(1)
	
	var proj: float4x4 {
		return .persp(
			fov: self.fov,
			asp: self.asp,
			z0: self.z0,
			z1: self.z1
		)
	}
	var view: float4x4 {
		var view = float4x4.pos(self.pos) * .mag(self.mag)
		view *= .zrot(self.rot.z)
		view *= .yrot(self.rot.y)
		view *= .xrot(self.rot.x)
		return view
	}
	
	var cam: xcamera {
		let proj = self.proj
		let view = self.view
		return xcamera(
			proj: proj,
			view: view,
			invproj: proj.inv,
			invview: view.inv,
			res: self.res
		)
	}
	
}
