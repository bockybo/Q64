import MetalKit


struct Model {
	var meshes: [MTKMesh]
	var instances: [MDL] = []
	var nid: Int {return self.instances.count}
	subscript(i: Int) -> MDL {
		get {return self.instances[i]}
		set(id) {self.instances[i] = id}
	}
}
