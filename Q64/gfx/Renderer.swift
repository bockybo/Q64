import MetalKit


// TODO:
// point light shadows w/ vertex amplification
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
	
	static let tile_w = 16
	static let tile_h = 16
	static let threadsize = sizeof(float.self) * 2
	static let atomicsize = sizeof(uint.self)
	static var groupsize: Int {
		let tptg = Self.tile_w * Self.tile_h
		let bptg = Self.atomicsize + Self.threadsize*tptg
		return 16 * (1 + (bptg - 1)/16)
	}
	
	let mode = Mode.deferred_classic
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
		
		let scnbuf = util.buffer(len: sizeof(xscene.self), label: "scene buffer")
		let mdlbuf = util.buffer(len: sizeof(xmodel.self) * Int(MAX_NMODEL), label: "model buffer")
		let lgtbuf = util.buffer(len: sizeof(xlight.self) * Int(MAX_NLIGHT), label: "light buffer")
		
		var models: [Model] = []
		
		var nclight: Int = 0
		var nilight: Int = 0
		var nlight: Int {return 1 + self.nclight + self.nilight}
		var nshade: Int {return 1 + self.nclight + 6*self.nilight}
		
		mutating func copy(_ scene: Scene) {
			
			var scn = scene.scn
			let mdls = scene.models.reduce([], {$0 + $1.mdls})
			let lgts = scene.lights.map {$0.lgt}
			
			self.scnbuf.write(&scn, length: sizeof(xscene.self))
			self.mdlbuf.write(mdls, length: sizeof(xmodel.self) * mdls.count)
			self.lgtbuf.write(lgts, length: sizeof(xlight.self) * lgts.count)
			
			self.models = scene.models
			self.nclight = scene.clights.count
			self.nilight = scene.ilights.count
			
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
				descr.usage				= []
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
					descr.usage				= []
					descr.storageMode		= .private
					descr.textureType		= .type2DMultisampleArray
					descr.sampleCount		= Int(msaa)
				}
				self.wrtdep = util.texture(label: "multisampled shadowmap depths") {
					descr in
					setup(descr)
					descr.pixelFormat		= Renderer.fmt_depth
					descr.usage				= []
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
	
	
	private let materials = lib.shaders.frgbufx_gbuf.makeArgumentEncoder(
		bufferIndex: 0,
		bufferOptions: .storageModeManaged
	)
	
	private func writematerials(_ materials: [Material]) {
		assert(materials.count <= MAX_NMATERIAL)
		let n = Material.nproperty
		for (matID, material) in materials.enumerated() {
			let textures = material.textures
			var defaults = material.defaults
			let i = 2 * n * matID
			self.materials.arg.setTextures(textures, range: i..<i+n)
			self.materials.arg.setBytes(&defaults, length: sizeof(defaults), index: i+n)
		}
		self.materials.buf.didModifyRange(0..<self.materials.arg.encodedLength)
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
			enc.draw(model.meshes, iid: iid, nid: model.nid)
			iid += model.nid
		}
	}
	
	private func dispatchcull(enc: MTLRenderCommandEncoder) {
		enc.setTBuffer(self.flt.scnbuf, index: 2)
		enc.setTBuffer(self.flt.lgtbuf, index: 3)
		enc.setThreadgroupMemoryLength(Self.groupsize, offset: 0, index: 0)
		enc.dispatchThreadsPerTile(MTLSizeMake(Self.tile_w, Self.tile_h, 1))
	}
	
	private func drawvolumes(
		enc: MTLRenderCommandEncoder,
		quadstate: MTLRenderPipelineState,
		volstate:  MTLRenderPipelineState
	) {
		// TODO: use hemispheres for cones
		enc.setFrontFacing(.clockwise)
		enc.setVBuffer(self.flt.lgtbuf, index: 3)
		enc.setDS(lib.states.dsbufx_quad)
		enc.setPS(quadstate)
		enc.draw(lib.lightmesh.quad, iid: 0, nid: 1)
		enc.setDS(lib.states.dsbufx_vol)
		enc.setPS(volstate)
		enc.draw(lib.lightmesh.icos, iid: 1, nid: self.flt.nlight - 1)
	}
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		self.rotate()
		
		self.cmdque.commit(label: "commit: shadow gen") {
			buf in
			
			buf.pass(label: "pass: shadow gen", descr: util.passdescr {
				descr in
				self.shadowmaps.attach(to: descr)
				descr.renderTargetArrayLength = min(Int(MAX_NSHADE), self.flt.nshade)
			}) {enc in
				enc.setCullMode(.back)
				enc.setFrontFacing(.clockwise)
				enc.setVBuffer(self.flt.lgtbuf, index: 3)
				enc.setVBuffer(self.flt.scnbuf, index: 2)
				enc.setVBuffer(self.flt.mdlbuf, index: 1)
				enc.setDS(lib.states.dsx_shade)
				var lid: uint = 0
				enc.setPS(lib.states.psx_shade1)
				while lid < 1+self.flt.nclight {
					enc.setVBytes(&lid, index: 4)
					self.drawgeometry(enc: enc)
					lid += 1
				}
				enc.setPS(lib.states.psx_shade6)
				enc.setVertexAmplificationCount(6, viewMappings: nil)
				while lid < self.flt.nlight {
					enc.setVBytes(&lid, index: 4)
					self.drawgeometry(enc: enc)
					lid += 1
				}
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
					descr.tileWidth  = Self.tile_w
					descr.tileHeight = Self.tile_h
					descr.threadgroupMemoryLength = Self.groupsize
				}
			}) {enc in
				
				enc.setStencilReferenceValue(0xFF)
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
					enc.setDS(lib.states.dsfwdc_light)
					enc.setPS(lib.states.psfwdc_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					break
					
				case .forward_tiled:
					enc.setDS(lib.states.dsx_prepass)
					enc.setPS(lib.states.psfwdp_depth)
					self.drawgeometry(enc: enc)
					enc.setPS(lib.states.psfwdp_cull)
					self.dispatchcull(enc: enc)
					enc.setDS(lib.states.dsfwdp_light)
					enc.setPS(lib.states.psfwdp_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					break
					
				case .deferred_classic:
					enc.setDS(lib.states.dsx_prepass)
					enc.setPS(lib.states.psbufx_gbuf)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					self.drawvolumes(
						enc: enc,
						quadstate: lib.states.psbufc_quad,
						volstate:  lib.states.psbufc_vol)
					break
					
				case .deferred_tiled:
					enc.setDS(lib.states.dsx_prepass)
					enc.setPS(lib.states.psbufx_gbuf)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					enc.setPS(lib.states.psbufp_cull)
					self.dispatchcull(enc: enc)
					self.drawvolumes(
						enc: enc,
						quadstate: lib.states.psbufp_quad,
						volstate:  lib.states.psbufp_vol)
					break
					
				}
				
			}
			
			buf.present(drawable)

		}
		
	}
	
}
