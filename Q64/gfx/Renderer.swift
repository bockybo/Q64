import MetalKit


class Renderer: NSObject, MTKViewDelegate {
	
	private let gpulock = DispatchSemaphore(value: 1)
	private let cmdque = lib.device.makeCommandQueue()!
	private var scene: Scene
	init(_ view: RenderView) {
		self.scene = view.ctrl.scene
		super.init()
		self.mtkView(view, drawableSizeWillChange: view.frame.size)
		view.preferredFramesPerSecond = cfg.fps
		view.delegate = self
	}
	
	func draw(in view: MTKView) {
		let buf = self.cmdque.makeCommandBuffer()!
		buf.addCompletedHandler {_ in self.gpulock.signal()}
		self.gpulock.wait()
		self.draw(in: view, with: buf)
		buf.present(view.currentDrawable!)
		buf.commit()
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		self.res = uint2(
			uint(2 * view.frame.size.width),
			uint(2 * view.frame.size.height))
		self.scene.cam.asp = float(size.width / size.height)
		view.colorPixelFormat = Renderer.fmt_color
		view.depthStencilPixelFormat = Renderer.fmt_depth
	}
	
	
	static let fmt_gbuf_alb = MTLPixelFormat.rgba8Unorm
	static let fmt_gbuf_nml = MTLPixelFormat.rgba8Snorm
	static let fmt_gbuf_dep = MTLPixelFormat.rg32Float
	static let fmt_color = MTLPixelFormat.bgra8Unorm
	static let fmt_depth = MTLPixelFormat.depth32Float_stencil8
	static let fmt_shade = MTLPixelFormat.depth32Float
	
	private let shadepass: MTLRenderPassDescriptor = {
		let pass = MTLRenderPassDescriptor()
		pass.depthAttachment.loadAction  = .clear
		pass.depthAttachment.storeAction = .store
		pass.depthAttachment.texture = lib.texture(
			fmt: Renderer.fmt_shade,
			res: uint2(cfg.shdqlt),
			storage: .private,
			usage: [.shaderRead, .renderTarget])
		return pass
	}()
	
	private let lightpass: MTLRenderPassDescriptor = {
		let pass = MTLRenderPassDescriptor()
		pass.stencilAttachment.loadAction  		= .clear
		pass.stencilAttachment.storeAction 		= .dontCare
		pass.depthAttachment.loadAction  		= .clear
		pass.depthAttachment.storeAction 		= .dontCare
		pass.colorAttachments[0].loadAction		= .clear
		pass.colorAttachments[0].storeAction 	= .store
		pass.colorAttachments[1].storeAction 	= .dontCare
		pass.colorAttachments[2].storeAction 	= .dontCare
		pass.colorAttachments[3].storeAction 	= .dontCare
		return pass
	}()
	var res = uint2(0, 0) {didSet {
		self.lightpass.colorAttachments[1].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_alb,
			res: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "alb+shd"
		)
		self.lightpass.colorAttachments[2].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_nml,
			res: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "nml+shn"
		)
		self.lightpass.colorAttachments[3].texture = lib.texture(
			fmt: Renderer.fmt_gbuf_dep,
			res: self.res,
			storage: .memoryless,
			usage: [.shaderRead, .renderTarget],
			label: "dep"
		)
	}}
	
	private let shadepipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["shade"]!
		descr.depthAttachmentPixelFormat = Renderer.fmt_shade
	}
	private let gbufpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["gbuf"]!
		descr.fragmentFunction	= lib.frgshaders["gbuf"]!
		Renderer.attachgbuf(descr)
	}
	private let quadpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["quad"]!
		descr.fragmentFunction	= lib.frgshaders["light"]!
		Renderer.attachgbuf(descr)
	}
	private let icospipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["icos"]!
		descr.fragmentFunction	= lib.frgshaders["light"]!
		Renderer.attachgbuf(descr)
	}
	private let maskpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["mask"]!
		Renderer.attachgbuf(descr)
	}
	private static func attachgbuf(_ descr: MTLRenderPipelineDescriptor) {
		descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
		descr.colorAttachments[0].pixelFormat 	= Renderer.fmt_color
		descr.colorAttachments[1].pixelFormat 	= Renderer.fmt_gbuf_alb
		descr.colorAttachments[2].pixelFormat 	= Renderer.fmt_gbuf_nml
		descr.colorAttachments[3].pixelFormat 	= Renderer.fmt_gbuf_dep
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
	private let icosdepth = lib.depthstate {descr in
		descr.depthCompareFunction							= .greater
		descr.frontFaceStencil.stencilCompareFunction		= .notEqual
		descr.backFaceStencil.stencilCompareFunction		= .notEqual
	}
	
	private let quadmesh = meshlib.quad(dim: float3(2, 2, 0), descr: lib.vtxdescrs["base"]!)
	private let icosmesh = meshlib.icos(dim: 12/(sqrtf(3) * (3+sqrtf(5))), descr: lib.vtxdescrs["base"]!)
	
	
	private func draw(in view: MTKView, with buf: MTLCommandBuffer) {
		self.lightpass.colorAttachments[0].texture	= view.currentDrawable!.texture
		self.lightpass.depthAttachment.texture		= view.depthStencilTexture!
		self.lightpass.stencilAttachment.texture	= view.depthStencilTexture!
		
		buf.pass(label: "shade", descr: self.shadepass) {enc in
			enc.setState(self.shadepipe, self.shadedepth, cull: .front)
			enc.setDepthBias(0.001, slopeScale: 5, clamp: 0.02)
			
			var ctm = self.scene.sun.ctm
			enc.setVertexBytes(&ctm, length: sizeof(ctm), index: 2)
			
			enc.setVertexBuffer(self.scene.uniforms.buf, offset: 0, index: 1)
			var iid = 0
			for mdl in self.scene.mdls {
				for mesh in mdl.meshes {
					enc.draw(mesh: mesh, prim: mdl.prim, iid: iid, nid: mdl.nid)
				}
				iid += mdl.nid
			}
			
		}
		
		buf.pass(label: "light", descr: self.lightpass) {enc in
			enc.setStencilReferenceValue(128)
			enc.setFrontFacing(.counterClockwise)
			
			var lgt = self.scene.sun.ctm
			var cam = self.scene.cam.ctm
			enc.setVertexBytes(&cam, length: sizeof(cam), index: 3)
			enc.setVertexBytes(&lgt, length: sizeof(lgt), index: 2)
			
			enc.setState(self.gbufpipe, self.gbufdepth, cull: .back)
			enc.setFragmentTexture(self.shadepass.depthAttachment.texture!, index: 0)
			
			enc.setVertexBuffer(self.scene.uniforms.buf, offset: 0, index: 1)
			enc.setFragmentBuffer(self.scene.uniforms.buf, offset: 0, index: 1)
			
			var iid = 0
			for mdl in self.scene.mdls {
				enc.setFragmentTexture(mdl.material.alb, index: 1)
				enc.setFragmentTexture(mdl.material.nml, index: 2)
				enc.setFragmentTexture(mdl.material.rgh, index: 3)
				enc.setFragmentTexture(mdl.material.mtl, index: 4)
				for mesh in mdl.meshes {
					enc.draw(mesh: mesh, prim: mdl.prim, iid: iid, nid: mdl.nid)
				}
				iid += mdl.nid
			}
			
			var inv = cam.inverse
			var eye = self.scene.cam.pos
			enc.setFragmentBytes(&inv, length: sizeof(inv), index: 3)
			enc.setFragmentBytes(&eye, length: sizeof(eye), index: 4)
			
			enc.setFragmentBytes(&self.res, length: sizeof(self.res), index: 5)
			enc.setFragmentBuffer(self.scene.lights.buf, offset: 0, index: 2)
			enc.setVertexBuffer(self.scene.lights.buf, offset: 0, index: 2)
			
			enc.setState(self.quadpipe, self.quaddepth, cull: .front)
			enc.draw(mesh: self.quadmesh, iid: 0, nid: 1)
			enc.setState(self.maskpipe, self.maskdepth, cull: .none)
			enc.draw(mesh: self.icosmesh, iid: 1, nid: self.scene.lights.count-1)
			enc.setState(self.icospipe, self.icosdepth, cull: .front)
			enc.draw(mesh: self.icosmesh, iid: 1, nid: self.scene.lights.count-1)
		
		}
		
		// TODO:
		// materials on submeshes
		// spot lights
		// multiple shadowmaps
		// unify lighting
		// alpha in deferred???
		// gamma correction
		// ambient occlusion
		// particles
		// sync & multithread
		// msaa maybe?
		// other post processing?
		// renderer proto (so forward, deferred, deferred tiled)
		// then org models, lighting; scene graph
		
	}
	
}
