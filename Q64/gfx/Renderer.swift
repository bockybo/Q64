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
	
	static let nflight = 3
	
	static let max_nmaterial = 32
	static let max_nmodel = 1024
	
	static let max_nlight = 256
	static let max_nshade = 16
	static let shadowquality = 16384 / 2
	
	static let tile_w = 16
	static let tile_h = 16
	
	static let fmt_color	= MTLPixelFormat.bgra8Unorm_srgb
	static let fmt_depth	= MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade	= MTLPixelFormat.depth32Float
	static let fmt_dep		= MTLPixelFormat.r32Float
	static let fmt_alb		= MTLPixelFormat.rgba8Unorm
	static let fmt_nml		= MTLPixelFormat.rgba8Snorm
	static let fmt_mat		= MTLPixelFormat.rgba8Unorm
	
	let mode = Mode.classic_deferred
	enum Mode {
		case classic_forward
		case classic_deferred
		case tiled_forward
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
		
		let cambuf = util.buffer(len: sizeof(CAM.self), label: "camera buffer")
		let mdlbuf = util.buffer(len: sizeof(MDL.self) * Renderer.max_nmodel, label: "model buffer")
		let lgtbuf = util.buffer(len: sizeof(LGT.self) * Renderer.max_nlight, label: "light buffer")
		
		var models: [Model] = []
		var nlight: Int = 0
		
		mutating func copy(_ scene: Scene) {
			
			var cam = scene.camera.cam
			self.cambuf.write(&cam, length: sizeof(cam))
			
			let mdls = scene.models.reduce([], {$0 + $1.mdls})
			self.models = scene.models
			self.mdlbuf.write(mdls, length: mdls.count * sizeof(MDL.self))
			
			let lgts = scene.lights.map {$0.lgt}
			self.nlight = lgts.count
			self.lgtbuf.write(lgts, length: self.nlight * sizeof(LGT.self))
			
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
	
	
	private let materials = lib.shaders.frg_gbuf.makeArgumentEncoder(
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
			case .classic_forward:
				break
			case .classic_deferred:
				self.fb_dep = util.framebuf(res: res, fmt: Self.fmt_dep, label: "texture: dep")
				self.fb_alb = util.framebuf(res: res, fmt: Self.fmt_alb, label: "texture: alb")
				self.fb_nml = util.framebuf(res: res, fmt: Self.fmt_nml, label: "texture: nml")
				self.fb_mat = util.framebuf(res: res, fmt: Self.fmt_mat, label: "texture: mat")
				break
			case .tiled_forward:
				self.fb_dep = util.framebuf(res: res, fmt: Self.fmt_dep, label: "texture: dep")
				break
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
			for lid in 0 ..< 1 + self.scene.clights.count {
				descr.depthAttachment.slice = lid
				buf.pass(label: "pass: shade \(lid)", descr: descr) {
					enc in
					enc.setCull(mode: .back, wind: .clockwise)
					enc.setStates(ps: lib.states.psshade, ds: lib.states.dsshade)
					enc.setVBuffer(self.flt.lgtbuf, offset: lid * sizeof(LGT.self), index: 2)
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
					
				case .classic_forward:
					buf.pass(label: "pass: light & drawable", descr: descr) {
						enc in
						enc.setCull(mode: .back, wind: .counterClockwise)
						enc.setStates(ps: lib.states.psfwd, ds: lib.states.dsfwd)
						enc.setFBuffer(self.materials.buf, index: 0)
						enc.setVBuffer(self.flt.cambuf, index: 2)
						enc.setFBuffer(self.flt.cambuf, index: 2)
						enc.setVBuffer(self.flt.mdlbuf, index: 1)
						enc.setFBuffer(self.flt.lgtbuf, index: 3)
						var nlight = uint(self.flt.nlight)
						enc.setFBytes(&nlight, index: 4)
						enc.setFragmentTexture(self.shadowmaps, index: 0)
						self.setmaterial(enc: enc)
						self.render(enc: enc)
					}
					break
					
				case .classic_deferred:
					buf.pass(label: "pass: light & drawable", descr: util.passdescr(descr) {
						descr in
						descr.colorAttachments[1].texture = self.fb_dep
						descr.colorAttachments[2].texture = self.fb_alb
						descr.colorAttachments[3].texture = self.fb_nml
						descr.colorAttachments[4].texture = self.fb_mat
						for i in 1..<5 {
							descr.colorAttachments[i].loadAction  = .dontCare
							descr.colorAttachments[i].storeAction = .dontCare
						}
					}) {enc in
						enc.setStencilReferenceValue(1)

						enc.setCull(mode: .back, wind: .counterClockwise)
						enc.setStates(ps: lib.states.psgbuf, ds: lib.states.dsgbuf)
						enc.setVBuffer(self.flt.cambuf, index: 2)
						enc.setVBuffer(self.flt.mdlbuf, index: 1)
						enc.setFBuffer(self.materials.buf, index: 0)
						self.setmaterial(enc: enc)
						self.render(enc: enc)
						
						enc.setFrontFacing(.clockwise)
						enc.setFBuffer(self.flt.cambuf, index: 2)
						enc.setFBuffer(self.flt.lgtbuf, index: 3)
						enc.setVBuffer(self.flt.lgtbuf, index: 3)
						enc.setFragmentTexture(self.shadowmaps, index: 0)
						
						var iid = 0, nid = 1
						enc.setDepthStencilState(lib.states.dsquad)
						enc.setRenderPipelineState(lib.states.psquad)
						enc.draw(lib.lightmesh.quad, iid: iid, nid: nid)
						iid += nid; nid = self.scene.clights.count
						enc.setDepthStencilState(lib.states.dsvolume)
						enc.setRenderPipelineState(lib.states.psvolume)
						enc.draw(lib.lightmesh.cone, iid: iid, nid: nid)
						iid += nid; nid = self.scene.ilights.count
						enc.draw(lib.lightmesh.icos, iid: iid, nid: nid)

					}
					break
					
				case .tiled_forward:
					
					let tile_w = Renderer.tile_w
					let tile_h = Renderer.tile_h
					var tgsize = sizeof(uint.self) + 2*sizeof(float.self) * tile_w*tile_h
					tgsize += 16 - tgsize%16
					
					buf.pass(label: "pass: light & drawable", descr: util.passdescr(descr) {
						descr in
						descr.colorAttachments[1].texture = self.fb_dep
						descr.colorAttachments[1].loadAction  = .dontCare
						descr.colorAttachments[1].storeAction = .dontCare
						descr.tileWidth  = tile_w
						descr.tileHeight = tile_h
						descr.threadgroupMemoryLength = tgsize
					}) {enc in
						
						enc.setCull(mode: .back, wind: .counterClockwise)
						
						enc.setVBuffer(self.flt.mdlbuf, index: 1)
						enc.setVBuffer(self.flt.cambuf, index: 2)
						enc.setTBuffer(self.flt.cambuf, index: 2)
						enc.setTBuffer(self.flt.lgtbuf, index: 3)
						enc.setFBuffer(self.materials.buf, index: 0)
						enc.setFBuffer(self.flt.cambuf, index: 2)
						enc.setFBuffer(self.flt.lgtbuf, index: 3)
						enc.setFragmentTexture(self.shadowmaps, index: 0)
						var nlight = uint(self.flt.nlight)
						enc.setTBytes(&nlight, index: 4)
						enc.setThreadgroupMemoryLength(tgsize, offset: 0, index: 0)
						
						enc.setDepthStencilState(lib.states.dsdepth)
						enc.setRenderPipelineState(lib.states.psdepth)
						self.render(enc: enc)
						enc.setRenderPipelineState(lib.states.pscull)
						enc.dispatchThreadsPerTile(MTLSizeMake(tile_w, tile_h, 1))
						enc.setDepthStencilState(lib.states.dstiled)
						enc.setRenderPipelineState(lib.states.pstiled)
						self.setmaterial(enc: enc)
						self.render(enc: enc)
						
					}
					break
					
			}
			
			buf.present(drawable)

		}
		
	}
	
	
}
