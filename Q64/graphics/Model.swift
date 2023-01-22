import MetalKit


class Model: Renderable {
	
	struct Material {
		var hue = v3f(1, 1, 1)
		var diff: f32 = 1
		var spec: f32 = 0
		var shine: f32 = 1
	}
	var mat = Material()
	
	var ctm: m4f = .idt
	var ett: Entity?
	
	init(ett: Entity? = nil) {
		self.ett = ett
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		var ctm = (self.ett?.ctm ?? .idt) * self.ctm
		enc.setVertexBytes(&ctm, length: util.sizeof(m4f.self), index: 1)
		enc.setFragmentBytes(&self.mat, length: util.sizeof(m4f.self), index: 1)
		for mesh in self.meshes {
			mesh.render(enc: enc)
		}
	}
	
	private var meshes: [Mesh] = []
	func add(_ mesh: Mesh) {self.meshes.append(mesh)}
	func add(_ meshes: [Mesh]) {self.meshes += meshes}
	
}
