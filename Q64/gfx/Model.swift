import MetalKit


class Model {
	let buf: MTLBuffer
	private var arr: [Entity]
	var meshes: [MTKMesh]
	var material: Material
	var type: MTLPrimitiveType
	
	init(
		_ arr: [Entity] = [],
		cap: Int = 1,
		meshes: [MTKMesh] = [],
		material: Material = Material(),
		type: MTLPrimitiveType = .triangle
	) {
		self.arr = arr
		self.buf = lib.device.makeBuffer(
			length: max(cap, arr.count) * util.sizeof(MVTX.self),
			options: .storageModeShared
		)!
		self.meshes = meshes
		self.material = material
		self.type = type
	}
	
	func draw(enc: MTLRenderCommandEncoder) {
		memcpy(self.buf.contents(), self.uniforms, self.size)
		enc.setVertexBuffer(self.buf, offset: 0, index: 1)
		for mesh in self.meshes {
			enc.draw(mesh, type: self.type, num: self.count)
		}
	}
	
	var uniforms: [MVTX] {return self.arr.map {$0.uniform}}
	
	var count: Int {return self.arr.count}
	var size: Int {return self.count * util.sizeof(MVTX.self)}
	var cap: Int {return self.buf.length / util.sizeof(MVTX.self)}
	
	subscript(i: Int) -> Entity {
		get {return self.arr[i]}
		set(ett) {self.arr[i] = ett}
	}
	func add(_ ett: Entity) -> Bool {
		return self.add([ett])
	}
	func add(_ arr: [Entity]) -> Bool{
		self.arr += arr
		let ovf = self.count - self.cap
		if ovf <= 0 {return true}
		self.arr.removeLast(ovf)
		return false
	}
	func rem(_ i: Int) {
		self.arr.remove(at: i)
	}
	func clear() {self.arr = []}
	
}


struct Material {
	var tex: MTLTexture = lib.white1x1
	var ambi = float3(0)
	var diff = float3(1)
	var spec = float3(0)
	var shine: float = 1
	
	func render(enc: MTLRenderCommandEncoder) {
		var mfrg = MFRG(
			ambi: self.ambi,
			diff: self.diff,
			spec: self.spec,
			shine: self.shine
		)
		mfrg.render(enc: enc)
		enc.setFragmentTexture(self.tex, index: 0)
	}
	
}
