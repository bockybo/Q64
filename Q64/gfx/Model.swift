import MetalKit


struct Model {
//	var meshes: [MTKMesh]
//	var instances: [MDL] = []
//	var nid: Int {return self.instances.count}
//	subscript(i: Int) -> MDL {
//		get {return self.instances[i]}
//		set(id) {self.instances[i] = id}
//	}
	
	var meshes: [MTKMesh]
	var instances: [Instance]
	init(meshes: [MTKMesh], _ instances: [Instance] = []) {
		self.meshes = meshes
		self.instances = instances
	}
	
	var nid: Int {return self.instances.count}
	subscript(i: Int) -> Instance {
		get {return self.instances[i]}
		set(instance) {self.instances[i] = instance}
	}
	
	var mdls: [MDL] {return self.instances.map {$0.mdl}}
	
}

struct Instance {
	var matID: Int
	var ctm: float4x4 = .I
	var mdl: MDL {
		return MDL(
			ctm: self.ctm,
			inv: self.ctm.inverse,
			matID: uint(self.matID)
		)
	}
}
