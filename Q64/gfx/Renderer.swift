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
	static let fmt_nml		= MTLPixelFormat.rgba8Snorm
	static let fmt_mat		= MTLPixelFormat.rgba8Unorm
	
	static let nflight = 3
	
	static let max_nmaterial = 32
	static let max_nmodel = 1024
	
	static let max_nlight = 32
	static let max_nshade = 32
	
	static let shadow_size = 16384 / 8
	static let shadow_msaa = 2
	
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
		case forward_plus
		case deferred_classic
		case deferred_plus
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
		
		let scnbuf = util.buffer(len: sizeof(SCN.self), label: "scene buffer")
		let mdlbuf = util.buffer(len: sizeof(MDL.self) * Renderer.max_nmodel, label: "model buffer")
		let lgtbuf = util.buffer(len: sizeof(LGT.self) * Renderer.max_nlight, label: "light buffer")
		
		var models: [Model] = []
		var nclight: Int = 0
		var nilight: Int = 0
		
		mutating func copy(_ scene: Scene) {
			
			var scn = scene.scn
			let mdls = scene.models.reduce([], {$0 + $1.mdls})
			let lgts = scene.lights.map {$0.lgt}
			
			self.scnbuf.write(&scn, length: sizeof(SCN.self))
			self.mdlbuf.write(mdls, length: mdls.count * sizeof(MDL.self))
			self.lgtbuf.write(lgts, length: lgts.count * sizeof(LGT.self))
			
			self.models = scene.models
			self.nclight = scene.clights.count
			self.nilight = scene.ilights.count
			
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
			self.rdmmt = util.texture(label: "resolved shadowmap moments") {descr in
				descr.pixelFormat		= Renderer.fmt_shade
				descr.arrayLength		= Renderer.max_nshade
				descr.width				= size
				descr.height			= size
				descr.usage				= [.renderTarget, .shaderRead, .shaderWrite]
				descr.storageMode		= .private
				descr.textureType		= .type2DArray
			}
			self.rddep = util.texture(label: "resolved shadowmap depths") {
				descr in
				descr.pixelFormat		= Renderer.fmt_depth
				descr.arrayLength		= Renderer.max_nshade
				descr.width				= size
				descr.height			= size
				descr.usage				= []
				descr.storageMode		= .private
				descr.textureType		= .type2DArray
			}
			if msaa == 1 {
				self.wrtmmt = nil
				self.wrtdep = nil
			}
			else {
				self.wrtmmt = util.texture(label: "multisampled shadowmap moments") {descr in
					descr.pixelFormat		= Renderer.fmt_shade
					descr.arrayLength		= Renderer.max_nshade
					descr.width				= size
					descr.height			= size
					descr.usage				= []
					descr.storageMode		= .private
					descr.textureType		= .type2DMultisampleArray
					descr.sampleCount		= msaa
				}
				self.wrtdep = util.texture(label: "multisampled shadowmap depths") {
					descr in
					descr.pixelFormat		= Renderer.fmt_depth
					descr.arrayLength		= Renderer.max_nshade
					descr.width				= size
					descr.height			= size
					descr.usage				= []
					descr.storageMode		= .memoryless
					descr.textureType		= .type2DMultisampleArray
					descr.sampleCount		= msaa
				}
			}
		}
		
	}
	
	
	private let materials = lib.shaders.frgbufx_gbuf.makeArgumentEncoder(
		bufferIndex: 0,
		bufferOptions: .storageModeManaged
	)
	
	private func writematerials(_ materials: [Material]) {
		assert(materials.count <= Self.max_nmaterial)
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
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let res = uint2(uint(size.width), uint(size.height))
		self.scene.camera.res = res
		self.resize(res: res)
		if view.isPaused {view.draw()}
	}
	
	
	var framebuf: [MTLTexture] = []
	private func resize(res: uint2) {
		switch self.mode {
		case .forward_classic:
			break
		case .forward_plus:
			self.framebuf = util.framebuf(res: res, [
				(label: "fb: dep", fmt: Self.fmt_dep),
			])
			break
		case .deferred_classic:
			self.framebuf = util.framebuf(res: res, [
				(label: "fb: dep", fmt: Self.fmt_dep),
				(label: "fb: alb", fmt: Self.fmt_alb),
				(label: "fb: nml", fmt: Self.fmt_nml),
				(label: "fb: mat", fmt: Self.fmt_mat),
			])
			break
		case .deferred_plus:
			self.framebuf = util.framebuf(res: res, [
				(label: "fb: dep", fmt: Self.fmt_dep),
				(label: "fb: alb", fmt: Self.fmt_alb),
				(label: "fb: nml", fmt: Self.fmt_nml),
				(label: "fb: mat", fmt: Self.fmt_mat),
			])
			break
		}
	}
	
	
	private func drawgeometry(enc: MTLRenderCommandEncoder) {
		var iid = 0
		for model in self.flt.models {
			enc.draw(model.meshes, iid: iid, nid: model.nid)
			iid += model.nid
		}
	}
	private func drawshadows(enc: MTLRenderCommandEncoder, lid: Int) {
		enc.setCullMode(.back)
		enc.setFrontFacing(.clockwise)
		enc.setVBuffer(self.flt.lgtbuf, offset: lid * sizeof(LGT.self), index: 3)
		enc.setVBuffer(self.flt.mdlbuf, index: 1)
		enc.setPS(lib.states.psx_shade)
		enc.setDS(lib.states.dsx_shade)
		self.drawgeometry(enc: enc)
	}
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		self.rotate()
		
		// whole commit can be one for loop of passes per light
		// technically wouldn't even need a scene ref or separate shadowmaps
		// but icos have no shadowmaps rn so wait a sec
		self.cmdque.commit(label: "commit: shade") {
			buf in
			
			if Self.shadow_msaa == 1 {
				let descr = util.passdescr {
					descr in
					descr.colorAttachments[0].loadAction  = .clear
					descr.colorAttachments[0].storeAction = .store
					descr.colorAttachments[0].texture = self.shadowmaps.rdmmt
					descr.depthAttachment.loadAction  = .dontCare
					descr.depthAttachment.storeAction = .dontCare
					descr.depthAttachment.texture = self.shadowmaps.rddep
				}
				for lid in 0..<min(Self.max_nshade, 1 + self.flt.nclight) {
					descr.colorAttachments[0].slice = lid
					descr.depthAttachment.slice = lid
					buf.pass(label: "pass: shade \(lid)", descr: descr) {
						enc in
						self.drawshadows(enc: enc, lid: lid)
					}
				}
			} else {
				let descr = util.passdescr {
					descr in
					descr.colorAttachments[0].loadAction  = .clear
					descr.colorAttachments[0].storeAction = .multisampleResolve
					descr.colorAttachments[0].texture = self.shadowmaps.wrtmmt!
					descr.colorAttachments[0].resolveTexture = self.shadowmaps.rdmmt
					descr.depthAttachment.loadAction  = .dontCare
					descr.depthAttachment.storeAction = .multisampleResolve
					descr.depthAttachment.texture = self.shadowmaps.wrtdep!
					descr.depthAttachment.resolveTexture = self.shadowmaps.rddep
				}
				for lid in 0..<min(Self.max_nshade, 1 + self.flt.nclight) {
					descr.colorAttachments[0].slice = lid
					descr.colorAttachments[0].resolveSlice = lid
					descr.depthAttachment.slice = lid
					descr.depthAttachment.resolveSlice = lid
					buf.pass(label: "pass: shade \(lid)", descr: descr) {
						enc in
						self.drawshadows(enc: enc, lid: lid)
					}
				}
			}
			
		}
		
		self.cmdque.commit(label: "commit: light & drawable") {
			buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			guard let drawable = view.currentDrawable else {return}
			
			let descr = util.passdescr {descr in
				util.attach(self.framebuf, to: descr)
				descr.colorAttachments[0].texture		= drawable.texture
				descr.colorAttachments[0].loadAction	= .clear
				descr.colorAttachments[0].storeAction	= .store
				descr.depthAttachment.texture			= view.depthStencilTexture!
				descr.depthAttachment.loadAction		= .dontCare
				descr.depthAttachment.storeAction		= .dontCare
				descr.stencilAttachment.texture			= view.depthStencilTexture!
				descr.stencilAttachment.loadAction		= .dontCare
				descr.stencilAttachment.storeAction		= .dontCare
				if (self.mode == .forward_plus || self.mode == .deferred_plus) {
					descr.tileWidth  = Self.tile_w
					descr.tileHeight = Self.tile_h
					descr.threadgroupMemoryLength = Self.groupsize
				}
			}
			
			switch self.mode {
					
			case .forward_classic:
				buf.pass(label: "pass: [fwd0] light & drawable", descr: descr) {
					enc in
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps.rdmmt, index: 0)
					enc.setCullMode(.back)
					enc.setFrontFacing(.counterClockwise)
					enc.setStencilReferenceValue(1)
					
					enc.setDS(lib.states.dsfwdc_light)
					enc.setPS(lib.states.psfwdc_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					
				}
				break
				
			case .forward_plus:
				descr.colorAttachments[1].loadAction = .clear
				buf.pass(label: "pass: [fwd+] light & drawable", descr: descr) {
					enc in
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps.rdmmt, index: 0)
					enc.setCullMode(.back)
					enc.setFrontFacing(.counterClockwise)
					enc.setStencilReferenceValue(1)
					
					enc.setDS(lib.states.dsx_prepass)
					enc.setPS(lib.states.psfwdp_depth)
					self.drawgeometry(enc: enc)
					
					enc.setPS(lib.states.psx_cull)
					enc.setThreadgroupMemoryLength(Self.groupsize, offset: 0, index: 0)
					enc.dispatchThreadsPerTile(MTLSizeMake(Self.tile_w, Self.tile_h, 1))
					
					enc.setDS(lib.states.dsfwdp_light)
					enc.setPS(lib.states.psfwdp_light)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					
				}
				break
				
			case .deferred_classic:
				buf.pass(label: "pass: [buf0] light & drawable", descr: descr) {
					enc in
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setVBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps.rdmmt, index: 0)
					enc.setCullMode(.back)
					enc.setStencilReferenceValue(1)
					
					enc.setFrontFacing(.counterClockwise)
					enc.setPS(lib.states.psbufx_gbuf)
					enc.setDS(lib.states.dsx_prepass)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					
					enc.setFrontFacing(.clockwise)
					var iid = 0, nid = 1
					enc.setDS(lib.states.dsbufx_quad)
					enc.setPS(lib.states.psbufc_quad)
					enc.draw(lib.lightmesh.quad, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nclight
					enc.setDS(lib.states.dsbufx_vol)
					enc.setPS(lib.states.psbufc_vol)
					enc.draw(lib.lightmesh.cone, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nilight
					enc.draw(lib.lightmesh.icos, iid: iid, nid: nid)
					
				}
				break
				
			case .deferred_plus:
				buf.pass(label: "pass: [buf+] light & drawable", descr: descr) {
					enc in
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setVBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps.rdmmt, index: 0)
					enc.setCullMode(.back)
					enc.setStencilReferenceValue(1)
					
					enc.setFrontFacing(.counterClockwise)
					enc.setPS(lib.states.psbufx_gbuf)
					enc.setDS(lib.states.dsx_prepass)
					self.setmaterials(enc: enc)
					self.drawgeometry(enc: enc)
					
					enc.setPS(lib.states.psx_cull)
					enc.setThreadgroupMemoryLength(Self.groupsize, offset: 0, index: 0)
					enc.dispatchThreadsPerTile(MTLSizeMake(Self.tile_w, Self.tile_h, 1))
					
					enc.setFrontFacing(.clockwise)
					var iid = 0, nid = 1
					enc.setDS(lib.states.dsbufx_quad)
					enc.setPS(lib.states.psbufp_quad)
					enc.draw(lib.lightmesh.quad, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nclight
					enc.setDS(lib.states.dsbufx_vol)
					enc.setPS(lib.states.psbufp_vol)
					enc.draw(lib.lightmesh.cone, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nilight
					enc.draw(lib.lightmesh.icos, iid: iid, nid: nid)
					
				}
				break
				
			}
			
			buf.present(drawable)

		}
		
	}
	
	
}
