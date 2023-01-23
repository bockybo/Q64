import MetalKit


struct Model: Renderable {
	let texture: MTLTexture?
	
	var ctm: m4f = .idt
	var hue: v4f = v4f(1, 1, 1, 1)
	var diff: f32 = 1
	var spec: f32 = 0
	var shine: f32 = 1
	
	var ett: Entity?
	
	static let textureldr = MTKTextureLoader(device: lib.device)
	
	init(
		_ meshes: [Mesh] = [],
		ett: Entity? = nil,
		texture: String? = nil
	) {
		self.meshes = meshes
		self.ett = ett
		if let url = util.url(texture) {
			self.texture = try! Model.textureldr.newTexture(
				URL: url,
				options: nil
			)
		} else {
			self.texture = nil
		}
	}
	
	struct Uniform {
		let ctm: m4f
		let hue: v4f
		let diff: f32
		let spec: f32
		let shine: f32
	}
	var uniform: Uniform {
		return Uniform(
			ctm: (self.ett?.ctm ?? .idt) * self.ctm,
			hue: self.hue,
			diff: self.diff,
			spec: self.spec,
			shine: self.shine
		)
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		if let texture = self.texture {
			enc.setFragmentTexture(texture, index: 0)
			enc.setFragmentSamplerState(lib.sstate, index: 0)
			enc.setRenderPipelineState(lib.rstate_text)
		} else {
			enc.setRenderPipelineState(lib.rstate_main)
		}
		var uniform = self.uniform
		enc.setVertexBytes(&uniform, length: util.sizeof(uniform), index: 1)
		for mesh in self.meshes {
			mesh.render(enc: enc)
		}
	}
	
	private var meshes: [Mesh] = []
	mutating func add(_ mesh: Mesh) {self.meshes.append(mesh)}
	mutating func add(_ meshes: [Mesh]) {self.meshes += meshes}
	
}
