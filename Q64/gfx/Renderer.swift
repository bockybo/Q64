import MetalKit


// TODO:
// pipeline on gpu?
// clustered forward & deferred
// order independent transparancy
// particles
// parallel encoding
// post processing?
//  screenspace ao?
//  msaa?
//  bloom?
// then org models, lighting; scene graph


class Renderer: NSObject, MTKViewDelegate {
	
	static let fmt_color	= MTLPixelFormat.bgra8Unorm_srgb
	static let fmt_depth	= MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade	= MTLPixelFormat.rg32Float
	static let fmt_dep		= MTLPixelFormat.r32Float
	static let fmt_alb		= MTLPixelFormat.rgba8Unorm
	static let fmt_nml		= MTLPixelFormat.rgba16Snorm
	static let fmt_mat		= MTLPixelFormat.rg8Unorm
	
	static let nflight = 3
	
	static let shadow_size = 16384 / 8
	static let shadow_msaa = 1
	
	static let tiledim = MTLSizeMake(16, 16, 1)
	static let tilesize = align(to: 16,
								sizeof(uint.self) +
								sizeof(float.self) * 2)
	
	let mode = Mode.forward_tiled
	enum Mode {
		case forward_classic
		case forward_tiled
		case deferred_classic
		case deferred_tiled
	}
	
	private let semaphore = DispatchSemaphore(value: Renderer.nflight)
	private let cmdque = lib.device.makeCommandQueue()!
	private let scene: Scene
	init(_ view: MTKView, scene: Scene) {
		self.scene = scene
		super.init()
		self.mtkView(view, drawableSizeWillChange: view.drawableSize)
		
		// TODO: make dynamically updateable
		self.writematerials(self.scene.materials)
		
	}
	
	
	private var flts = (0..<Renderer.nflight).map {_ in Flight()}
	private var iflt = Renderer.nflight - 1
	private var flt: Flight {return self.flts[self.iflt]}
	private func rotate() {
		self.iflt = (self.iflt + 1) % Renderer.nflight
		self.flts[self.iflt].copy(self.scene)
	}
	private struct Flight {
		let scnbuf = util.buffer(
			length: sizeof(xscene.self),
			options: .storageModeManaged,
			label: "scene buffer"
		)
		let mdlbuf = util.buffer(
			length: sizeof(xmodel.self) * Int(MAX_NMODEL),
			options: .storageModeManaged,
			label: "model buffer"
		)
		let lgtbuf = util.buffer(
			length: sizeof(xlight.self) * Int(MAX_NLIGHT),
			options: .storageModeManaged,
			label: "light buffer"
		)
		var models: [Model] = []
		var nclight: Int = 0
		var nilight: Int = 0
		var nlight: Int {return 1 + self.nclight +   self.nilight}
		var nshade: Int {return 1 + self.nclight + 6*self.nilight}
		mutating func copy(_ scene: Scene) {
			var scn = scene.scn
			self.scnbuf.write(&scn)
			self.mdlbuf.write(scene.models.reduce([], {$0 + $1.mdls}))
			self.lgtbuf.write(scene.lights.map {$0.lgt})
			self.models = scene.models
			self.nclight = scene.clights.count
			self.nilight = scene.ilights.count
			assert(self.nshade <= Int(MAX_NSHADE))
		}
	}
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let res = uint2(uint(size.width), uint(size.height))
		self.scene.camera.res = res
		self.framebuffer = Framebuffer(res, mode: self.mode)
		if view.isPaused {view.draw()}
	}
	
	private var framebuffer: Framebuffer!
	private struct Framebuffer {
		let textures: [MTLTexture]
		
		init(_ res: uint2, mode: Mode) {
			let tex = {(label: String, fmt: MTLPixelFormat) in util.texture(label: label) {
				descr in
				descr.textureType	= .type2D
				descr.pixelFormat	= fmt
				descr.storageMode	= .memoryless
				descr.usage			= [.renderTarget, .shaderRead]
				descr.width			= Int(res.x)
				descr.height		= Int(res.y)
			}}
			switch mode {
			case .forward_classic:
				self.textures = []
				break
			case .forward_tiled:
				self.textures = [
					tex("fb: dep", Renderer.fmt_dep),
				]
				break
			case .deferred_classic:
				self.textures = [
					tex("fb: dep", Renderer.fmt_dep),
					tex("fb: alb", Renderer.fmt_alb),
					tex("fb: nml", Renderer.fmt_nml),
					tex("fb: mat", Renderer.fmt_mat),
				]
				break
			case .deferred_tiled:
				self.textures = [
					tex("fb: dep", Renderer.fmt_dep),
					tex("fb: alb", Renderer.fmt_alb),
					tex("fb: nml", Renderer.fmt_nml),
					tex("fb: mat", Renderer.fmt_mat),
				]
				break
			}
		}
		
		func attach(to descr: MTLRenderPassDescriptor) {
			for (i, texture) in self.textures.enumerated() {
				descr.colorAttachments[i+1].texture = texture
				descr.colorAttachments[i+1].loadAction  = .dontCare
				descr.colorAttachments[i+1].storeAction = .dontCare
			}
		}
		
	}
	
	private let shadowmaps = Shadowmaps(
		size: Renderer.shadow_size,
		msaa: Renderer.shadow_msaa
	)
	private struct Shadowmaps {
		let rdmmt: MTLTexture
		let rddep: MTLTexture
		let wrtmmt: MTLTexture?
		let wrtdep: MTLTexture?
		
		init(size: Int, msaa: Int = 1) {
			
			let setup = {(descr: MTLTextureDescriptor) in
				descr.width				= size
				descr.height			= size
				descr.arrayLength		= Int(MAX_NSHADE)
			}
			
			self.rdmmt = util.texture(label: "resolved shadowmap moments") {
				descr in
				setup(descr)
				descr.pixelFormat		= Renderer.fmt_shade
				descr.usage				= [.renderTarget, .shaderRead]
				descr.storageMode		= .private
				descr.textureType		= .type2DArray
			}
			self.rddep = util.texture(label: "resolved shadowmap depths") {
				descr in
				setup(descr)
				descr.pixelFormat		= Renderer.fmt_depth
				descr.usage				= [.renderTarget]
				descr.storageMode		= .private
				descr.textureType		= .type2DArray
			}
			
			if msaa == 1 {
				self.wrtmmt = nil
				self.wrtdep = nil
			}
			else {
				self.wrtmmt = util.texture(label: "multisampled shadowmap moments") {
					descr in
					setup(descr)
					descr.pixelFormat		= Renderer.fmt_shade
					descr.usage				= [.renderTarget]
					descr.storageMode		= .private
					descr.textureType		= .type2DMultisampleArray
					descr.sampleCount		= Int(msaa)
				}
				self.wrtdep = util.texture(label: "multisampled shadowmap depths") {
					descr in
					setup(descr)
					descr.pixelFormat		= Renderer.fmt_depth
					descr.usage				= [.renderTarget]
					descr.storageMode		= .memoryless
					descr.textureType		= .type2DMultisampleArray
					descr.sampleCount		= Int(msaa)
				}
			}
			
		}
		
		var multisampled: Bool {return self.wrtmmt != nil}
		func attach(to descr: MTLRenderPassDescriptor) {
			if !self.multisampled {
				descr.colorAttachments[0].loadAction  = .clear
				descr.colorAttachments[0].storeAction = .store
				descr.colorAttachments[0].texture = self.rdmmt
				descr.depthAttachment.loadAction  = .dontCare
				descr.depthAttachment.storeAction = .dontCare
				descr.depthAttachment.texture = self.rddep
			} else {
				descr.colorAttachments[0].loadAction  = .clear
				descr.colorAttachments[0].storeAction = .multisampleResolve
				descr.colorAttachments[0].texture = self.wrtmmt!
				descr.colorAttachments[0].resolveTexture = self.rdmmt
				descr.depthAttachment.loadAction  = .dontCare
				descr.depthAttachment.storeAction = .multisampleResolve
				descr.depthAttachment.texture = self.wrtdep!
				descr.depthAttachment.resolveTexture = self.rddep
			}
		}
		
	}
	
	
	private let materials = lib.shaders.frgfwdc_light.makeArgumentBuffer(
		at: 0,
		options: .storageModeManaged
	)
	private func writematerials(_ materials: [Material]) {
		assert(materials.count <= MAX_NMATERIAL)
		let n = Material.nproperty
		for (matID, material) in materials.enumerated() {
			let textures = material.textures
			var defaults = material.defaults
			let i = 2 * n * matID
			self.materials.enc.setTextures(textures, range: i..<i+n)
			self.materials.enc.setBytes(&defaults, index: i+n)
		}
		self.materials.buf.didModifyAll()
	}
	
	
	private func setmaterials(enc: MTLRenderCommandEncoder) {
		for mat in self.scene.materials {
			for case let texture? in mat.textures {
				enc.useResource(texture, usage: .read, stages: .fragment)
			}
		}
	}
	
	private func drawgeometry(enc: MTLRenderCommandEncoder) {
		var iid = 0
		for model in self.flt.models {
			for mesh in model.meshes {
				enc.draw(mesh, iid: iid, nid: model.nid)
			}
			iid += model.nid
		}
	}
	
	private func drawshadows(enc: MTLRenderCommandEncoder, count: Int, start: Int) {
		for lid in start..<start+count {
			var lid = uint(lid)
			enc.setVBytes(&lid, index: 4)
			self.drawgeometry(enc: enc)
		}
	}
	
	private func dispatchcull(enc: MTLRenderCommandEncoder) {
		enc.setTBuffer(self.flt.scnbuf, index: 2)
		enc.setTBuffer(self.flt.lgtbuf, index: 3)
		enc.setThreadgroupMemoryLength(Self.tilesize, offset: 0, index: 0)
		enc.dispatchThreadsPerTile(Self.tiledim)
	}
	
	private let lightvol = util.mesh.icos(
		dim: float3(12 / (sqrtf(3) * (3+sqrtf(5)))),
		descr: lib.vtxdescrs.base
	)
	private func drawgbuffer(
		enc: MTLRenderCommandEncoder,
		quad_state: MTLRenderPipelineState,
		icos_state: MTLRenderPipelineState
	) {
		enc.setFrontFacing(.clockwise)
		enc.setVBuffer(self.flt.lgtbuf, index: 3)
		enc.setDS(lib.dstates.bufx_quad)
		enc.setPS(quad_state)
		enc.draw(6, iid: 0, nid: 1)
		enc.setDS(lib.dstates.bufx_icos)
		enc.setPS(icos_state)
		enc.draw(self.lightvol, iid: 1, nid: self.flt.nlight - 1)
	}
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		self.rotate()
		
		self.cmdque.commit(label: "commit: shadow gen") {
			buf in

			buf.pass(label: "pass: shadow gen", descr: util.passdescr {
				descr in
				self.shadowmaps.attach(to: descr)
				descr.renderTargetArrayLength = self.flt.nshade
			}) {enc in
				enc.setCullMode(.back)
				enc.setFrontFacing(.clockwise)
				enc.setVBuffer(self.flt.lgtbuf, index: 3)
				enc.setVBuffer(self.flt.scnbuf, index: 2)
				enc.setVBuffer(self.flt.mdlbuf, index: 1)
				enc.setDS(lib.dstates.shade)
				enc.setPS(lib.pstates.shade1)
				self.drawshadows(enc: enc, count: 1, start: 0)
				self.drawshadows(enc: enc, count: self.flt.nclight, start: 1)
				enc.setAmplification(count: 6)
				enc.setPS(lib.pstates.shade6)
				self.drawshadows(enc: enc, count: self.flt.nilight, start: 1+self.flt.nclight)
			}
		}
		
		self.cmdque.commit(label: "commit: light & drawable") {
			buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			guard let drawable = view.currentDrawable else {return}

			buf.pass(label: "pass: light & drawable", descr: util.passdescr {
				descr in
				self.framebuffer.attach(to: descr)
				descr.colorAttachments[0].texture		= drawable.texture
				descr.colorAttachments[0].loadAction	= .clear
				descr.colorAttachments[0].storeAction	= .store
				descr.depthAttachment.texture			= view.depthStencilTexture!
				descr.depthAttachment.loadAction		= .dontCare
				descr.depthAttachment.storeAction		= .dontCare
				descr.stencilAttachment.texture			= view.depthStencilTexture!
				descr.stencilAttachment.loadAction		= .dontCare
				descr.stencilAttachment.storeAction		= .dontCare
				if self.mode == .forward_tiled || self.mode == .deferred_tiled {
					descr.tileWidth  = Self.tiledim.width
					descr.tileHeight = Self.tiledim.height
					descr.threadgroupMemoryLength = Self.tilesize
				}
			}) {enc in

				enc.setStencilReferenceValue(128)
				enc.setCullMode(.back)
				enc.setFrontFacing(.counterClockwise)

				enc.setFragmentTexture(self.shadowmaps.rdmmt, index: 0)
				enc.setFBuffer(self.materials.buf, index: 0)
				enc.setVBuffer(self.flt.mdlbuf, index: 1)
				enc.setVBuffer(self.flt.scnbuf, index: 2)
				enc.setFBuffer(self.flt.scnbuf, index: 2)
				enc.setFBuffer(self.flt.lgtbuf, index: 3)

				switch self.mode {

				case .forward_classic:
					enc.setDS(lib.dstates.fwdc_light)
					enc.setPS(lib.pstates.fwdc_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					break

				case .forward_tiled:
					enc.setDS(lib.dstates.prepass)
					enc.setPS(lib.pstates.fwdp_depth)
					self.drawgeometry(enc: enc)
					enc.setPS(lib.pstates.fwdp_cull)
					self.dispatchcull(enc: enc)
					enc.setDS(lib.dstates.fwdp_light)
					enc.setPS(lib.pstates.fwdp_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					break

				case .deferred_classic:
					enc.setDS(lib.dstates.prepass)
					enc.setPS(lib.pstates.bufx_gbuf)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					self.drawgbuffer(
						enc: enc,
						quad_state: lib.pstates.bufc_quad,
						icos_state: lib.pstates.bufc_icos)
					break

				case .deferred_tiled:
					enc.setDS(lib.dstates.prepass)
					enc.setPS(lib.pstates.bufx_gbuf)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					enc.setPS(lib.pstates.bufp_cull)
					self.dispatchcull(enc: enc)
					self.drawgbuffer(
						enc: enc,
						quad_state: lib.pstates.bufp_quad,
						icos_state: lib.pstates.bufp_icos)
					break

				}

			}

			buf.present(drawable)

		}
		
	}
	
}
