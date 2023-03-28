import MetalKit


class Model {
	var meshes: [MTKMesh]
	var instances: [Instance]
	init(meshes: [MTKMesh], _ instances: [Instance] = []) {
		self.meshes = meshes
		self.instances = instances
	}
	
	var mdls: [xmodel] {return self.instances.map {$0.mdl}}
	var nid: Int {return self.instances.count}
	subscript(i: Int) -> Instance {
		get {return self.instances[i]}
		set(instance) {self.instances[i] = instance}
	}
	
}

struct Instance {
	var matID: Int
	var ctm: float4x4 = .I
	var mdl: xmodel {
		return xmodel(
			ctm: self.ctm,
			inv: self.ctm.inverse,
			mat: uint(self.matID)
		)
	}
}
