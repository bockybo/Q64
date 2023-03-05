import MetalKit


// TODO:
// vertex amplification!
// point light shadows
// materials on submeshes
// alpha in deferred???
// screenspace ambient occlusion
// particles
// parallel encoding?
// msaa maybe?
// post processing?
//  msaa?
//  bloom?
// renderer proto (so forward, deferred, deferred tiled)
// then org models, lighting; scene graph


class Renderer: NSObject, MTKViewDelegate {
	
	static let nflight = 1
	
	static let maxnmodel = 1024
	static let maxnlight = 128
	
	static let qshd_quad = 16384
	static let qshd_cone = 16384 / 4
	
	static let fmt_color = MTLPixelFormat.bgra8Unorm_srgb
	static let fmt_depth = MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade = MTLPixelFormat.depth32Float
	
	private let semaphore = DispatchSemaphore(value: Renderer.nflight)
	private let cmdque = lib.device.makeCommandQueue()!
	private var scene: Scene
	init(_ view: RenderView) {
		self.scene = view.ctrl.scene
		super.init()
		self.mtkView(view, drawableSizeWillChange: view.drawableSize)
	}
	
	
	private struct Flight {
		let cambuf = lib.buffer(sizeof(CAM.self), label: "scn")
		let mdlbuf = lib.buffer(sizeof(MDL.self) * Renderer.maxnmodel, label: "mdl")
		let lgtbuf = lib.buffer(sizeof(LGT.self) * Renderer.maxnlight, label: "lgt")
		func copy(_ scene: Scene) {
			var cam = scene.cam
			self.cambuf.write(&cam, length: sizeof(cam))
			self.mdlbuf.write(scene.mdls, length: scene.mdls.count * sizeof(MDL.self))
			self.lgtbuf.write(scene.lgts, length: scene.lgts.count * sizeof(LGT.self))
		}
		func bind(enc: MTLRenderCommandEncoder) {
			enc.setVertexBuffer(self.cambuf, offset: 0, index: 3)
			enc.setVertexBuffer(self.lgtbuf, offset: 0, index: 2)
			enc.setVertexBuffer(self.mdlbuf, offset: 0, index: 1)
			enc.setFragmentBuffer(self.cambuf, offset: 0, index: 3)
			enc.setFragmentBuffer(self.lgtbuf, offset: 0, index: 2)
			enc.setFragmentBuffer(self.mdlbuf, offset: 0, index: 1)
		}
	}
	private let flts = (0..<Renderer.nflight).map {_ in Flight()}
	private var iflt = Renderer.nflight - 1
	private func rotate() -> Flight {
		self.iflt = (self.iflt + 1) % Renderer.nflight
		self.flts[self.iflt].copy(self.scene)
		return self.flts[self.iflt]
	}
	
	
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
			descr.colorAttachments[1].storeAction 	= .dontCare
			descr.colorAttachments[2].storeAction 	= .dontCare
			descr.colorAttachments[3].storeAction 	= .dontCare
			descr.colorAttachments[4].storeAction 	= .dontCare
			descr.stencilAttachment.loadAction  	= .dontCare
			descr.stencilAttachment.storeAction 	= .dontCare
			descr.depthAttachment.loadAction  		= .dontCare
			descr.depthAttachment.storeAction 		= .dontCare
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
			self.alb = lib.tex.base(
				fmt: GBuf.fmt_alb,
				res: res,
				label: "alb",
				usage: [.shaderRead, .renderTarget],
				storage: .memoryless
			)
			self.nml = lib.tex.base(
				fmt: GBuf.fmt_nml,
				res: res,
				label: "nml",
				usage: [.shaderRead, .renderTarget],
				storage: .memoryless
			)
			self.mat = lib.tex.base(
				fmt: GBuf.fmt_mat,
				res: res,
				label: "mat",
				usage: [.shaderRead, .renderTarget],
				storage: .memoryless
			)
			self.dep = lib.tex.base(
				fmt: GBuf.fmt_dep,
				res: res,
				label: "dep",
				usage: [.shaderRead, .renderTarget],
				storage: .memoryless
			)
		}
	}
	private var gbuf: GBuf!
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let res = uint2(uint(size.width), uint(size.height))
		self.scene.camera.res = res
		self.gbuf = .init(res: res)
		view.colorPixelFormat = Renderer.fmt_color
		view.depthStencilPixelFormat = Renderer.fmt_depth
		if view.isPaused {view.draw()}
	}
	
	
	private let shadepipe = lib.pipestate {descr in
		descr.vertexFunction				= lib.vtxshaders["shade"]!
		descr.depthAttachmentPixelFormat 	= Renderer.fmt_shade
	}
	private let gbufpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["main"]!
		descr.fragmentFunction	= lib.frgshaders["gbuf"]!
		Renderer.GBuf.attach(descr)
	}
	private let maskpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["mask"]!
		Renderer.GBuf.attach(descr)
	}
	private let quadpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["quad"]!
		descr.fragmentFunction	= lib.frgshaders["quad"]!
		Renderer.GBuf.attach(descr)
	}
	private let icospipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["light"]!
		descr.fragmentFunction	= lib.frgshaders["icos"]!
		Renderer.GBuf.attach(descr)
	}
	private let conepipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["light"]!
		descr.fragmentFunction	= lib.frgshaders["cone"]!
		Renderer.GBuf.attach(descr)
	}
	
	private let shadedepth = lib.depthstate {descr in
		descr.isDepthWriteEnabled 							= true
		descr.depthCompareFunction 							= .lessEqual
	}
	private let gbufdepth = lib.depthstate {descr in
		descr.isDepthWriteEnabled							 = true
		descr.depthCompareFunction 							= .less
		descr.frontFaceStencil.depthStencilPassOperation	= .replace
		descr.backFaceStencil.depthStencilPassOperation		= .replace
	}
	private let quaddepth = lib.depthstate {descr in
		descr.frontFaceStencil.stencilCompareFunction		= .equal
		descr.backFaceStencil.stencilCompareFunction		= .equal
	}
	private let maskdepth = lib.depthstate {descr in
		descr.depthCompareFunction							= .less
		descr.frontFaceStencil.depthFailureOperation		= .incrementWrap
		descr.backFaceStencil.depthFailureOperation			= .decrementWrap
	}
	private let volumedepth = lib.depthstate {descr in
		descr.depthCompareFunction							= .greater
		descr.frontFaceStencil.stencilCompareFunction		= .notEqual
		descr.backFaceStencil.stencilCompareFunction		= .notEqual
	}
	
	
	private let quadmesh = lib.mesh.quad(
		dim: 2 * .xy,
		descr: lib.vtxdescrs["base"]!
	)
	private let icosmesh = lib.mesh.icos(
		dim: float3(12 / (sqrtf(3) * (3+sqrtf(5)))),
		descr: lib.vtxdescrs["base"]!
	)
	private let conemesh = lib.mesh.cone(
		dim: 1 + .xz,
		seg: uint2(20, 20),
		ctm: .xrot(-.pi/2) * .ypos(-0.5),
		descr: lib.vtxdescrs["base"]!
	) // origin at center not apex, docs lie
	
	
	func draw(in view: MTKView) {
		self.semaphore.wait()
		let flt = self.rotate()
		
		self.cmdque.commit(label: "shade") {buf in
			for i in 0..<self.scene.lighting.count {
				guard let shadowmap = self.scene.lighting.lights[i].shadowmap else {continue}
				buf.pass(label: "shade \(i)", descr: lib.passdescr {descr in
					descr.depthAttachment.loadAction  = .clear
					descr.depthAttachment.storeAction = .store
					descr.depthAttachment.texture = shadowmap
				}) {enc in
					enc.setVertexBuffer(flt.lgtbuf, index: 2)
					enc.setVertexBuffer(flt.mdlbuf, index: 1)
					enc.setVertexBufferOffset(i * sizeof(LGT.self), index: 2)
					enc.setCullMode(.front)
					enc.setFrontFacing(.counterClockwise)
					enc.setRenderPipelineState(self.shadepipe)
					enc.setDepthStencilState(self.shadedepth)
					var iid = 0
					for model in self.scene.models {
						for mesh in model.meshes {
							enc.draw(mesh: mesh, iid: iid, nid: model.count)
							iid += model.count
						}
					}
				}
			}
		} // you gotta do what you gotta do
		
		self.cmdque.commit(label: "light & drawable") {buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			guard let drawable = view.currentDrawable else {return}
			
			buf.pass(label: "light & drawable", descr: lib.passdescr {descr in
				self.gbuf.attach(descr)
				descr.colorAttachments[0].texture		= drawable.texture
				descr.depthAttachment.texture			= view.depthStencilTexture!
				descr.stencilAttachment.texture			= view.depthStencilTexture!
			}) {enc in
				enc.setFrontFacing(.counterClockwise)
				enc.setStencilReferenceValue(128)
				
				enc.setStates(self.gbufpipe, self.gbufdepth, cull: .back)
				enc.setVertexBuffer(flt.cambuf, index: 3)
				enc.setVertexBuffer(flt.mdlbuf, index: 1)
				var iid = 0
				for model in self.scene.models {
					var defaults = model.material.defaults
					let textures = model.material.textures
					// TODO: CAN NOT ACTUALLY WORK THIS WAY.  NEEDS TO BE BUFFERED
					enc.setFragmentBytes(&defaults, length: sizeof(defaults), index: 0)
					enc.setFragmentTextures(textures, range: 0..<textures.count)
					for mesh in model.meshes {
						enc.draw(mesh: mesh, iid: iid, nid: model.count)
						iid += model.count
					}
				}
				
				enc.setVFBuffers(flt.cambuf, index: 3)
				enc.setVFBuffers(flt.lgtbuf, index: 2)
				enc.setFragmentTextures(self.scene.lighting.lights.map {$0.shadowmap}, range: 0..<self.scene.lighting.count)
				
				iid = 0; var nid = self.scene.lighting.quad.count
				enc.setRenderPipelineState(self.quadpipe)
				enc.setDepthStencilState(self.quaddepth)
				enc.setCullMode(.front)
				enc.draw(mesh: self.quadmesh, nid: nid)
				
				iid += nid; nid = self.scene.lighting.cone.count
				enc.setRenderPipelineState(self.maskpipe)
				enc.setDepthStencilState(self.maskdepth)
				enc.setCullMode(.none)
				enc.draw(mesh: self.conemesh, iid: iid, nid: nid)
				iid += nid; nid = self.scene.lighting.icos.count
				enc.draw(mesh: self.icosmesh, iid: iid, nid: nid)
				
				enc.setCullMode(.front)
				enc.setDepthStencilState(self.volumedepth)
				enc.setRenderPipelineState(self.icospipe)
				enc.draw(mesh: self.icosmesh, iid: iid, nid: nid)
				nid = self.scene.lighting.cone.count; iid -= nid
				enc.setRenderPipelineState(self.conepipe)
				enc.draw(mesh: self.conemesh, iid: iid, nid: nid)
				
			}
			
			buf.present(drawable)
			
		}
		
	}
	
}
