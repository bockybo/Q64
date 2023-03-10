import MetalKit


// TODO:
// light culling w/ threadgroups; deferred+;
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
	var deferred = true
	
	static let nflight = 2
	
	static let max_nmaterial = 32
	static let max_nmodel = 1024
	static let max_nlight = max_nquad + max_ncone + max_nicos
	static let max_nquad = 2
	static let max_ncone = 32
	static let max_nicos = 64
	
	static let qshd_quad = 16384 / 2
	static let qshd_cone = 16384 / 4
	
	static let fmt_color = MTLPixelFormat.bgra8Unorm_srgb
	static let fmt_depth = MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade = MTLPixelFormat.depth32Float
	
	private let semaphore = DispatchSemaphore(value: Renderer.nflight)
	private let cmdque = lib.device.makeCommandQueue()!
	private let scene: Scene
	init(_ view: MTKView, scene: Scene) {
		self.scene = scene
		super.init()
		self.mtkView(view, drawableSizeWillChange: view.drawableSize)
	}
	
	
	private var flts = (0..<Renderer.nflight).map {_ in Flight()}
	private var iflt = Renderer.nflight - 1
	private var flt: Flight {return self.flts[self.iflt]}
	private func rotate() {
		self.iflt = (self.iflt + 1) % Renderer.nflight
		self.flts[self.iflt].copy(self.scene)
	}
	private struct Flight {
		
		let cambuf = util.buffer(len: sizeof(CAM.self), label: "scene buffer")
		let mdlbuf = util.buffer(len: sizeof(MDL.self) * Renderer.max_nmodel, label: "model buffer")
		let quadbuf = util.buffer(len: sizeof(LGT.self) * Renderer.max_nquad, label: "quad buffer")
		let conebuf = util.buffer(len: sizeof(LGT.self) * Renderer.max_ncone, label: "cone buffer")
		let icosbuf = util.buffer(len: sizeof(LGT.self) * Renderer.max_nicos, label: "icos buffer")
		
		var models: [Model] = []
		var nquad: Int = 0
		var ncone: Int = 0
		var nicos: Int = 0
		
		mutating func copy(_ scene: Scene) {
			
			var cam = scene.camera.cam
			self.cambuf.write(&cam, length: sizeof(cam))
			
			let mdls = scene.models.reduce([], {$0 + $1.instances})
			self.models = scene.models
			self.mdlbuf.write(mdls, length: mdls.count * sizeof(MDL.self))
			
			let quad = scene.lighting.quad.map {$0.lgt}
			let cone = scene.lighting.cone.map {$0.lgt}
			let icos = scene.lighting.icos.map {$0.lgt}
			self.nquad = quad.count
			self.ncone = cone.count
			self.nicos = icos.count
			self.quadbuf.write(quad, length: self.nquad * sizeof(LGT.self))
			self.conebuf.write(cone, length: self.ncone * sizeof(LGT.self))
			self.icosbuf.write(icos, length: self.nicos * sizeof(LGT.self))
			
		}
	}
	
	
	private var gbuf: GBuf?
	private struct GBuf {
		static let fmt_alb = MTLPixelFormat.rgba8Unorm_srgb
		static let fmt_nml = MTLPixelFormat.rgba16Snorm
		static let fmt_mat = MTLPixelFormat.rgba8Unorm
		static let fmt_dep = MTLPixelFormat.r32Float
		static func attach(_ descr: MTLRenderPipelineDescriptor) {
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat 	= Renderer.GBuf.fmt_alb
			descr.colorAttachments[2].pixelFormat 	= Renderer.GBuf.fmt_nml
			descr.colorAttachments[3].pixelFormat 	= Renderer.GBuf.fmt_mat
			descr.colorAttachments[4].pixelFormat 	= Renderer.GBuf.fmt_dep
		}
		func attach(_ descr: MTLRenderPassDescriptor) {
			descr.colorAttachments[0].loadAction	= .clear
			descr.colorAttachments[0].storeAction 	= .store
			descr.stencilAttachment.loadAction  	= .dontCare
			descr.stencilAttachment.storeAction 	= .dontCare
			descr.depthAttachment.loadAction  		= .dontCare
			descr.depthAttachment.storeAction 		= .dontCare
			descr.colorAttachments[1].loadAction 	= .dontCare
			descr.colorAttachments[2].loadAction 	= .dontCare
			descr.colorAttachments[3].loadAction 	= .dontCare
			descr.colorAttachments[4].loadAction 	= .dontCare
			descr.colorAttachments[1].storeAction 	= .dontCare
			descr.colorAttachments[2].storeAction 	= .dontCare
			descr.colorAttachments[3].storeAction 	= .dontCare
			descr.colorAttachments[4].storeAction 	= .dontCare
			descr.colorAttachments[1].texture		= self.alb
			descr.colorAttachments[2].texture		= self.nml
			descr.colorAttachments[3].texture		= self.mat
			descr.colorAttachments[4].texture		= self.dep
		}
		let alb: MTLTexture
		let nml: MTLTexture
		let mat: MTLTexture
		let dep: MTLTexture
		init(res: uint2) {
			self.alb = util.texture(label: "gbuffer albedo") {descr in
				descr.pixelFormat	= GBuf.fmt_alb
				descr.width			= Int(res.x)
				descr.height		= Int(res.y)
				descr.usage			= [.shaderRead, .renderTarget]
				descr.storageMode	= .memoryless
			}
			self.nml = util.texture(label: "gbuffer normal") {descr in
				descr.pixelFormat	= GBuf.fmt_nml
				descr.width			= Int(res.x)
				descr.height		= Int(res.y)
				descr.usage			= [.shaderRead, .renderTarget]
				descr.storageMode	= .memoryless
			}
			self.mat = util.texture(label: "gbuffer material") {descr in
				descr.pixelFormat	= GBuf.fmt_mat
				descr.width			= Int(res.x)
				descr.height		= Int(res.y)
				descr.usage			= [.shaderRead, .renderTarget]
				descr.storageMode	= .memoryless
			}
			self.dep = util.texture(label: "gbuffer depth") {descr in
				descr.pixelFormat	= GBuf.fmt_dep
				descr.width			= Int(res.x)
				descr.height		= Int(res.y)
				descr.usage			= [.shaderRead, .renderTarget]
				descr.storageMode	= .memoryless
			}
		}
	}
	
	
	private class states {
		
		static let psshade = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_shade"]!
			descr.depthAttachmentPixelFormat 			= Renderer.fmt_shade
			descr.inputPrimitiveTopology				= .triangle
		}
		static let psgbuf = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_main"]!
			descr.fragmentFunction						= lib.shaders["frg_gbuf"]!
			Renderer.GBuf.attach(descr)
		}
		static let psquad = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_quad"]!
			descr.fragmentFunction						= lib.shaders["frg_quad"]!
			Renderer.GBuf.attach(descr)
		}
		static let psicos = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_volume"]!
			descr.fragmentFunction						= lib.shaders["frg_icos"]!
			Renderer.GBuf.attach(descr)
		}
		static let pscone = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_volume"]!
			descr.fragmentFunction						= lib.shaders["frg_cone"]!
			Renderer.GBuf.attach(descr)
		}
		static let psfwd = util.pipestate {descr in
			descr.vertexFunction						= lib.shaders["vtx_main"]!
			descr.fragmentFunction						= lib.shaders["frg_fwd"]!
			descr.colorAttachments[0].pixelFormat		= Renderer.fmt_color
			descr.depthAttachmentPixelFormat			= Renderer.fmt_depth
		}
		
		static let dsshade = util.depthstate {descr in
			descr.isDepthWriteEnabled 							= true
			descr.depthCompareFunction 							= .lessEqual
		}
		static let dsgbuf = util.depthstate {descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction 							= .lessEqual
			descr.frontFaceStencil.depthStencilPassOperation	= .replace
			descr.backFaceStencil.depthStencilPassOperation		= .replace
		}
		static let dsquad = util.depthstate {descr in
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		static let dsvolume = util.depthstate {descr in
			descr.depthCompareFunction							= .greaterEqual
		}
		static let dsfwd = util.depthstate {descr in
			descr.isDepthWriteEnabled = true
			descr.depthCompareFunction = .less
		}
		
	}
	
	
	private let quad_shadowmaps = util.texture(label: "quad shadowmaps") {descr in
		descr.pixelFormat		= Renderer.fmt_shade
		descr.width				= Renderer.qshd_quad
		descr.height			= Renderer.qshd_quad
		descr.arrayLength		= Renderer.max_nquad
		descr.textureType		= .type2DArray
		descr.usage				= [.shaderRead, .renderTarget]
		descr.storageMode		= .private
	}
	private let cone_shadowmaps = util.texture(label: "cone shadowmaps") {descr in
		descr.pixelFormat		= Renderer.fmt_shade
		descr.width				= Renderer.qshd_cone
		descr.height			= Renderer.qshd_cone
		descr.arrayLength		= Renderer.max_ncone
		descr.textureType		= .type2DArray
		descr.usage				= [.shaderRead, .renderTarget]
		descr.storageMode		= .private
	}
	
	
	private lazy var mat_buf: MTLBuffer = {
		let mats = self.scene.materials
		assert(mats.count <= Renderer.max_nmaterial)
		let n = Material.nproperty
		let arg = lib.shaders["frg_gbuf"]!.makeArgumentEncoder(bufferIndex: 0)
		let buf = util.buffer(len: arg.encodedLength, opt: .storageModeManaged)
		arg.setArgumentBuffer(buf, offset: 0)
		for (matID, mat) in mats.enumerated() {
			let textures = mat.textures
			var defaults = mat.defaults
			let i = 2 * n * matID
			arg.setTextures(textures, range: i..<i+n)
			arg.setBytes(&defaults, length: sizeof(defaults), index: i+n)
		}
		buf.didModifyRange(0..<arg.encodedLength)
		return buf
	}()
	
	
	private func render(enc: MTLRenderCommandEncoder, lid: Int = 0) {
		var iid = 0
		for model in self.flt.models {
			enc.setVertexBufferOffset(iid * sizeof(MDL.self), index: 1)
			iid += model.nid
			for mesh in model.meshes {
				enc.draw(mesh: mesh, iid: lid, nid: model.nid)
			}
		}
	}
	private func setmaterial(enc: MTLRenderCommandEncoder) {
		enc.setFBuffer(self.mat_buf, index: 0)
		for mat in self.scene.materials {
			for case let texture? in mat.textures {
				enc.useResource(texture, usage: .read)
			}
		}
	}
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let res = uint2(uint(size.width), uint(size.height))
		self.scene.camera.res = res
		if self.deferred {self.gbuf = .init(res: res)}
		if view.isPaused {view.draw()}
	}
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		self.rotate()
		
		self.cmdque.commit(label: "commit: shade") {
			buf in
			
			buf.pass(label: "pass: shade quad", descr: util.passdescr {
				descr in
				descr.depthAttachment.loadAction  = .dontCare
				descr.depthAttachment.storeAction = .store
				descr.depthAttachment.texture = self.quad_shadowmaps
				descr.renderTargetArrayLength = self.flt.nquad
			}) {enc in
				enc.setCull(mode: .front, wind: .counterClockwise)
				enc.setStates(ps: states.psshade, ds: states.dsshade)
				enc.setVBuffer(self.flt.quadbuf, index: 2)
				enc.setVBuffer(self.flt.mdlbuf,  index: 1)
				for i in 0..<self.flt.nquad {self.render(enc: enc, lid: i)}
			}
			
			buf.pass(label: "pass: shade cones", descr: util.passdescr {
				descr in
				descr.depthAttachment.loadAction  = .dontCare
				descr.depthAttachment.storeAction = .store
				descr.depthAttachment.texture = self.cone_shadowmaps
				descr.renderTargetArrayLength = self.flt.ncone
			}) {enc in
				enc.setCull(mode: .front, wind: .counterClockwise)
				enc.setStates(ps: states.psshade, ds: states.dsshade)
				enc.setVBuffer(self.flt.conebuf, index: 2)
				enc.setVBuffer(self.flt.mdlbuf,  index: 1)
				for i in 0..<self.flt.ncone {self.render(enc: enc, lid: i)}
			}
			
		}
		
		self.cmdque.commit(label: "commit: light & drawable") {
			buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			guard let drawable = view.currentDrawable else {return}
			
			if self.deferred {
				buf.pass(label: "pass: light & drawable (deferred)", descr: util.passdescr {
					descr in
					self.gbuf!.attach(descr)
					descr.depthAttachment.texture			= view.depthStencilTexture!
					descr.stencilAttachment.texture			= view.depthStencilTexture!
					descr.colorAttachments[0].texture		= drawable.texture
				}) {enc in
					enc.setStencilReferenceValue(1)

					enc.setStates(ps: states.psgbuf, ds: states.dsgbuf)
					enc.setCull(mode: .back, wind: .counterClockwise)
					enc.setVBuffer(self.flt.cambuf, index: 3)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)
					self.setmaterial(enc: enc)
					self.render(enc: enc)
					
					enc.setFBuffer(self.flt.cambuf, index: 3)
					enc.setCull(mode: .back, wind: .clockwise)

					enc.setFragmentTexture(self.quad_shadowmaps, index: 0)
					enc.setVBuffer(self.flt.quadbuf, index: 2)
					enc.setFBuffer(self.flt.quadbuf, index: 2)
					enc.setStates(ps: states.psquad, ds: states.dsquad)
					enc.draw(mesh: lib.quadmesh, nid: self.flt.nquad)

					enc.setFragmentTexture(self.cone_shadowmaps, index: 0)
					enc.setVBuffer(self.flt.conebuf, index: 2)
					enc.setFBuffer(self.flt.conebuf, index: 2)
					enc.setStates(ps: states.pscone, ds: states.dsvolume)
					enc.draw(mesh: lib.conemesh, nid: self.flt.ncone)

					// TODO: icos shadows
					enc.setVBuffer(self.flt.icosbuf, index: 2)
					enc.setFBuffer(self.flt.icosbuf, index: 2)
					enc.setStates(ps: states.psicos, ds: states.dsvolume)
					enc.draw(mesh: lib.icosmesh, nid: self.flt.nicos)

				}
			}
			
			else {
				buf.pass(label: "pass: light & drawable (forward)", descr: view.currentRenderPassDescriptor!) {
					enc in
					enc.setCull(mode: .back, wind: .counterClockwise)
					enc.setStates(ps: states.psfwd, ds: states.dsfwd)

					enc.setVBuffer(self.flt.cambuf, index: 3)
					enc.setFBuffer(self.flt.cambuf, index: 3)
					enc.setVBuffer(self.flt.mdlbuf, index: 1)

					enc.setFBuffer(self.flt.quadbuf, index: 4)
					enc.setFBuffer(self.flt.conebuf, index: 5)
					enc.setFBuffer(self.flt.icosbuf, index: 6)
					enc.setFragmentTexture(self.quad_shadowmaps, index: 4)
					enc.setFragmentTexture(self.cone_shadowmaps, index: 5)
					enc.setFragmentTexture(self.cone_shadowmaps, index: 6) // TODO: icos shadows
					var nquad = self.flt.nquad
					var ncone = self.flt.ncone
					var nicos = self.flt.nicos
					enc.setFragmentBytes(&nquad, length: sizeof(nquad), index: 7)
					enc.setFragmentBytes(&ncone, length: sizeof(ncone), index: 8)
					enc.setFragmentBytes(&nicos, length: sizeof(nicos), index: 9)

					self.setmaterial(enc: enc)
					self.render(enc: enc)

				}
			}
			
			buf.present(drawable)
			
		}
		
	}
	
}
