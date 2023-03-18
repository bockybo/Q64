import MetalKit


// TODO:
// point light shadows w/ vertex amplification
// gbuffer transparancy???
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
	static let fmt_shade	= MTLPixelFormat.depth32Float
	static let fmt_dep		= MTLPixelFormat.r32Float
	static let fmt_alb		= MTLPixelFormat.rgba8Unorm
	static let fmt_nml		= MTLPixelFormat.rgba8Snorm
	static let fmt_mat		= MTLPixelFormat.rgba8Unorm
	
	static let nflight = 3
	
	static let max_nmaterial = 32
	static let max_nmodel = 1024
	
	static let max_nlight = 256
	static let max_nshade = 16
	static let shadowquality = 16384 / 2
	
	static let tile_w = 16
	static let tile_h = 16
	static let threadsize = sizeof(float.self) * 2
	static let atomicsize = sizeof(uint.self)
	static var groupsize: Int {
		let nthread = Renderer.tile_w * Renderer.tile_h
		let groupsize = Renderer.atomicsize + Renderer.threadsize*nthread
		return 16 * (1 + (groupsize - 1)/16)
	}
	static let threadgrid = MTLSizeMake(16, 16, 1)
	
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
			
			var scn = SCN(nlgt: uint(scene.lights.count), cam: scene.camera.cam)
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
	
	
	private let shadowmaps = util.texture(label: "shadowmaps") {descr in
		descr.usage				= [.shaderRead, .renderTarget]
		descr.storageMode		= .private
		descr.textureType		= .type2DArray
		descr.pixelFormat		= Renderer.fmt_shade
		descr.arrayLength		= Renderer.max_nshade
		descr.width				= Renderer.shadowquality
		descr.height			= Renderer.shadowquality
	}
	
	
	private let materials = lib.shaders.frgbufx_gbuf.makeArgumentEncoder(
		bufferIndex: 0,
		bufferOptions: .storageModeManaged
	)
	
	private func writematerials(_ materials: [Material]) {
		assert(materials.count <= Renderer.max_nmaterial)
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
	
	private func setmaterial(enc: MTLRenderCommandEncoder) {
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
	
	var fb_dep: MTLTexture?
	var fb_alb: MTLTexture?
	var fb_nml: MTLTexture?
	var fb_mat: MTLTexture?
	private func resize(res: uint2) {
		switch self.mode {
		case .forward_classic:
			break
		case .forward_plus:
			self.fb_dep = util.framebuf(res: res, fmt: Self.fmt_dep, label: "texture: dep")
			break
		case .deferred_classic:
			self.fb_dep = util.framebuf(res: res, fmt: Self.fmt_dep, label: "texture: dep")
			self.fb_alb = util.framebuf(res: res, fmt: Self.fmt_alb, label: "texture: alb")
			self.fb_nml = util.framebuf(res: res, fmt: Self.fmt_nml, label: "texture: nml")
			self.fb_mat = util.framebuf(res: res, fmt: Self.fmt_mat, label: "texture: mat")
			break
		case .deferred_plus:
			self.fb_dep = util.framebuf(res: res, fmt: Self.fmt_dep, label: "texture: dep")
			self.fb_alb = util.framebuf(res: res, fmt: Self.fmt_alb, label: "texture: alb")
			self.fb_nml = util.framebuf(res: res, fmt: Self.fmt_nml, label: "texture: nml")
			self.fb_mat = util.framebuf(res: res, fmt: Self.fmt_mat, label: "texture: mat")
		}
	}
	
	
	private func render(enc: MTLRenderCommandEncoder) {
		var iid = 0
		for model in self.flt.models {
			enc.draw(model.meshes, iid: iid, nid: model.nid)
			iid += model.nid
		}
	}
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		self.rotate()
		
		// whole commit can be one for loop of passes per light
		// technically wouldn't even need a scene ref or separate shadowmaps
		// but icos have no shadowmaps rn so wait a sec
		self.cmdque.commit(label: "commit: shade") {
			buf in

			let descr = util.passdescr {
				descr in
				descr.depthAttachment.loadAction  = .dontCare
				descr.depthAttachment.storeAction = .store
				descr.depthAttachment.texture = self.shadowmaps
			}
			for lid in 0 ..< 1 + self.flt.nclight {
				descr.depthAttachment.slice = lid
				buf.pass(label: "pass: shade \(lid)", descr: descr) {
					enc in
					enc.setCull(mode: .back, wind: .clockwise)
					enc.setStates(ps: lib.states.psx_shade, ds: lib.states.dsx_shade)
					enc.setVBuffer(self.flt.lgtbuf, offset: lid * sizeof(LGT.self), index: 3)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					self.render(enc: enc)
				}
			}

		}
		
		self.cmdque.commit(label: "commit: light & drawable") {
			buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			guard let drawable = view.currentDrawable else {return}
			
			let descr = util.passdescr {descr in
				descr.colorAttachments[0].texture		= drawable.texture
				descr.colorAttachments[0].loadAction	= .clear
				descr.colorAttachments[1].storeAction	= .store
				descr.depthAttachment.texture			= view.depthStencilTexture!
				descr.depthAttachment.loadAction		= .dontCare
				descr.depthAttachment.storeAction		= .dontCare
				descr.stencilAttachment.texture			= view.depthStencilTexture!
				descr.stencilAttachment.loadAction		= .dontCare
				descr.stencilAttachment.storeAction		= .dontCare
			}
			
			switch self.mode {
					
			case .forward_classic:
				buf.pass(label: "pass: [fwd0] light & drawable", descr: descr) {
					enc in
					enc.setCullMode(.back)
					enc.setFrontFacing(.counterClockwise)
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps, index: 0)
					
					enc.setStates(ps: lib.states.psfwdc_light, ds: lib.states.dsfwdx_light)
					self.setmaterial(enc: enc)
					self.render(enc: enc)
					
				}
				break
				
			case .forward_plus:
				descr.tileWidth  = Self.tile_w
				descr.tileHeight = Self.tile_h
				descr.threadgroupMemoryLength = Self.groupsize
				descr.colorAttachments[1].texture		= self.fb_dep
				descr.colorAttachments[1].loadAction 	= .dontCare
				descr.colorAttachments[1].storeAction	= .dontCare
				buf.pass(label: "pass: [fwd+] light & drawable", descr: descr) {
					enc in
					enc.setCullMode(.back)
					enc.setFrontFacing(.counterClockwise)
					enc.setStencilReferenceValue(1)
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps, index: 0)
					
					enc.setDepthStencilState(lib.states.dsx_prepass)
					enc.setRenderPipelineState(lib.states.psfwdp_depth)
					self.render(enc: enc)
					
					enc.setRenderPipelineState(lib.states.psfwdp_cull)
					enc.setThreadgroupMemoryLength(Self.groupsize, offset: 0, index: 0)
					enc.dispatchThreadsPerTile(Self.threadgrid)
					
					enc.setDepthStencilState(lib.states.dsfwdx_light)
					enc.setRenderPipelineState(lib.states.psfwdp_light)
					self.setmaterial(enc: enc)
					self.render(enc: enc)
					
				}
				break
				
			case .deferred_classic:
				descr.colorAttachments[1].texture = self.fb_dep
				descr.colorAttachments[2].texture = self.fb_alb
				descr.colorAttachments[3].texture = self.fb_nml
				descr.colorAttachments[4].texture = self.fb_mat
				for i in 1..<5 {
					descr.colorAttachments[i].loadAction  = .dontCare
					descr.colorAttachments[i].storeAction = .dontCare
				}
				buf.pass(label: "pass: [buf0] light & drawable", descr: descr) {
					enc in
					enc.setCullMode(.back)
					enc.setStencilReferenceValue(1)
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setVBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps, index: 0)
					
					enc.setFrontFacing(.counterClockwise)
					enc.setStates(ps: lib.states.psbufx_gbuf, ds: lib.states.dsx_prepass)
					self.setmaterial(enc: enc)
					self.render(enc: enc)
					
					enc.setFrontFacing(.clockwise)
					var iid = 0, nid = 1
					enc.setDepthStencilState(lib.states.dsbufx_quad)
					enc.setRenderPipelineState(lib.states.psbufc_quad)
					enc.draw(lib.lightmesh.quad, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nclight
					enc.setDepthStencilState(lib.states.dsbufx_vol)
					enc.setRenderPipelineState(lib.states.psbufc_vol)
					enc.draw(lib.lightmesh.cone, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nilight
					enc.draw(lib.lightmesh.icos, iid: iid, nid: nid)
					
				}
				break
				
			case .deferred_plus:
				descr.tileWidth  = Self.tile_w
				descr.tileHeight = Self.tile_h
				descr.threadgroupMemoryLength = Self.groupsize
				descr.colorAttachments[1].texture = self.fb_dep
				descr.colorAttachments[2].texture = self.fb_alb
				descr.colorAttachments[3].texture = self.fb_nml
				descr.colorAttachments[4].texture = self.fb_mat
				for i in 1..<5 {
					descr.colorAttachments[i].loadAction  = .dontCare
					descr.colorAttachments[i].storeAction = .dontCare
				}
				buf.pass(label: "pass: [buf+] light & drawable", descr: descr) {
					enc in
					enc.setCullMode(.back)
					enc.setStencilReferenceValue(1)
					
					enc.setFBuffer(self.materials.buf, index: 0)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					enc.setVBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.scnbuf, index: 2)
					enc.setFBuffer(self.flt.scnbuf, index: 2)
					enc.setTBuffer(self.flt.lgtbuf, index: 3)
					enc.setFBuffer(self.flt.lgtbuf, index: 3)
					enc.setVBuffer(self.flt.lgtbuf, index: 3)
					enc.setFragmentTexture(self.shadowmaps, index: 0)
					
					enc.setFrontFacing(.counterClockwise)
					enc.setStates(ps: lib.states.psbufx_gbuf, ds: lib.states.dsx_prepass)
					self.setmaterial(enc: enc)
					self.render(enc: enc)
					
					enc.setRenderPipelineState(lib.states.psbufp_cull)
					enc.setThreadgroupMemoryLength(Self.groupsize, offset: 0, index: 0)
					enc.dispatchThreadsPerTile(Self.threadgrid)
					
					enc.setFrontFacing(.clockwise)
					var iid = 0, nid = 1
					enc.setDepthStencilState(lib.states.dsbufx_quad)
					enc.setRenderPipelineState(lib.states.psbufp_quad)
					enc.draw(lib.lightmesh.quad, iid: iid, nid: nid)
					iid += nid; nid = self.flt.nclight
					enc.setDepthStencilState(lib.states.dsbufx_vol)
					enc.setRenderPipelineState(lib.states.psbufp_vol)
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
