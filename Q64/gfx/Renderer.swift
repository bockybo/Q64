import MetalKit


// TODO:
// spot lights - cone mesh?
// multiple shadowmaps
// proper materials, more than just props
// materials on submeshes
// alpha in deferred???
// gamma correction
// ambient occlusion
// particles
// parallel encoder?
// msaa maybe?
// other post processing?
// renderer proto (so forward, deferred, deferred tiled)
// then org models, lighting; scene graph


class Renderer: NSObject, MTKViewDelegate {
	
	static let nflight = 1
	
	static let maxnmodel = 1024
	static let maxnlight = 256
	
	static let qshd = 8192
	static let nshd = 8
	
	static let fmt_gbuf_alb = MTLPixelFormat.rgba8Unorm_srgb
	static let fmt_gbuf_nml = MTLPixelFormat.rgba16Snorm
	static let fmt_gbuf_mat = MTLPixelFormat.rgba8Unorm
	static let fmt_gbuf_dep = MTLPixelFormat.r32Float
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
		let scnbuf = lib.buffer(sizeof(Scene.SCN.self), label: "scn")
		let mdlbuf = lib.buffer(sizeof(Scene.MDL.self) * Renderer.maxnmodel, label: "mdl")
		let lgtbuf = lib.buffer(sizeof(Scene.LGT.self) * Renderer.maxnlight, label: "lgt")
		func copy(_ scene: Scene) {
			var scn = scene.cam.scn
			self.scnbuf.write(&scn, length: sizeof(scn))
			self.mdlbuf.write(scene.mdls, length: scene.mdls.count * sizeof(Scene.MDL.self))
			self.lgtbuf.write(scene.lgts, length: scene.lgts.count * sizeof(Scene.LGT.self))
		}
		func bind(enc: MTLRenderCommandEncoder) {
			enc.setVertexBuffer(self.scnbuf, offset: 0, index: 3)
			enc.setVertexBuffer(self.lgtbuf, offset: 0, index: 2)
			enc.setVertexBuffer(self.mdlbuf, offset: 0, index: 1)
			enc.setFragmentBuffer(self.scnbuf, offset: 0, index: 3)
			enc.setFragmentBuffer(self.lgtbuf, offset: 0, index: 2)
			enc.setFragmentBuffer(self.mdlbuf, offset: 0, index: 1)
		}
	}
	private let flts = (0..<Renderer.nflight).map {_ in Flight()}
	private var iflt = Renderer.nflight - 1
	private var flt: Flight {return self.flts[self.iflt]}
	
	private var shadepass = lib.passdescr {descr in
		descr.depthAttachment.loadAction  = .clear
		descr.depthAttachment.storeAction = .store
		descr.depthAttachment.texture = lib.tex.base(
			fmt: Renderer.fmt_shade,
			res: uint2(uint(Renderer.qshd)),
			label: "shadowmaps",
			usage: [.shaderRead, .renderTarget],
			storage: .private,
			nslices: Renderer.nshd
		)
		descr.renderTargetArrayLength = Renderer.nshd
	}
	
	private let lightpass = lib.passdescr {descr in
		descr.stencilAttachment.loadAction  	= .clear
		descr.stencilAttachment.storeAction 	= .dontCare
		descr.depthAttachment.loadAction  		= .clear
		descr.depthAttachment.storeAction 		= .dontCare
		descr.colorAttachments[0].loadAction	= .clear
		descr.colorAttachments[0].storeAction 	= .store
		descr.colorAttachments[1].storeAction 	= .dontCare
		descr.colorAttachments[2].storeAction 	= .dontCare
		descr.colorAttachments[3].storeAction 	= .dontCare
		descr.colorAttachments[4].storeAction 	= .dontCare
	}
	
	private let shadepipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["shade"]!
		descr.depthAttachmentPixelFormat = Renderer.fmt_shade
		descr.inputPrimitiveTopology = .triangle
		descr.maxVertexAmplificationCount = Renderer.nshd
		descr.rasterSampleCount = 1
	}
	private let gbufpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["main"]!
		descr.fragmentFunction	= lib.frgshaders["gbuf"]!
		Renderer.attachgbuf(descr)
	}
	private let quadpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["quad"]!
		descr.fragmentFunction	= lib.frgshaders["light"]!
		Renderer.attachgbuf(descr)
	}
	private let maskpipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["mask"]!
		Renderer.attachgbuf(descr)
	}
	private let icospipe = lib.pipestate {descr in
		descr.vertexFunction	= lib.vtxshaders["icos"]!
		descr.fragmentFunction	= lib.frgshaders["light"]!
		Renderer.attachgbuf(descr)
	}
	private static func attachgbuf(_ descr: MTLRenderPipelineDescriptor) {
		descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
		descr.colorAttachments[0].pixelFormat 	= Renderer.fmt_color
		descr.colorAttachments[1].pixelFormat 	= Renderer.fmt_gbuf_alb
		descr.colorAttachments[2].pixelFormat 	= Renderer.fmt_gbuf_nml
		descr.colorAttachments[3].pixelFormat 	= Renderer.fmt_gbuf_mat
		descr.colorAttachments[4].pixelFormat 	= Renderer.fmt_gbuf_dep
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
	private let spotdepth = lib.depthstate {descr in
		descr.depthCompareFunction							= .greater
		descr.frontFaceStencil.stencilCompareFunction		= .notEqual
		descr.backFaceStencil.stencilCompareFunction		= .notEqual
	}
	
	private let quadmesh = lib.mesh.quad(
		dim: float3(2, 2, 0),
		descr: lib.vtxdescrs["base"]!
	)
	private let icosmesh = lib.mesh.icos(
		dim: float3(12 / (sqrtf(3) * (3+sqrtf(5)))),
		descr: lib.vtxdescrs["base"]!
	)
	
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let res = uint2(uint(size.width), uint(size.height))
		self.scene.cam.res = res
		self.lightpass.colorAttachments[1].texture = lib.tex.base(
			fmt: Renderer.fmt_gbuf_alb,
			res: res,
			label: "alb",
			usage: [.shaderRead, .renderTarget],
			storage: .memoryless
		)
		self.lightpass.colorAttachments[2].texture = lib.tex.base(
			fmt: Renderer.fmt_gbuf_nml,
			res: res,
			label: "nml",
			usage: [.shaderRead, .renderTarget],
			storage: .memoryless
		)
		self.lightpass.colorAttachments[3].texture = lib.tex.base(
			fmt: Renderer.fmt_gbuf_mat,
			res: res,
			label: "mat",
			usage: [.shaderRead, .renderTarget],
			storage: .memoryless
		)
		self.lightpass.colorAttachments[4].texture = lib.tex.base(
			fmt: Renderer.fmt_gbuf_dep,
			res: res,
			label: "dep",
			usage: [.shaderRead, .renderTarget],
			storage: .memoryless
		)
		view.colorPixelFormat = Renderer.fmt_color
		view.depthStencilPixelFormat = Renderer.fmt_depth
		if view.isPaused {view.draw()}
	}
	
	
	func draw(in view: MTKView) {
		
		self.semaphore.wait()
		
		self.iflt = (self.iflt + 1) % Renderer.nflight
		self.flt.copy(self.scene)
		
		self.lightpass.colorAttachments[0].texture	= view.currentDrawable!.texture
		self.lightpass.depthAttachment.texture		= view.depthStencilTexture!
		self.lightpass.stencilAttachment.texture	= view.depthStencilTexture!
		
		self.cmdque.commit(label: "shade") {buf in
			buf.pass(label: "shade", descr: self.shadepass) {enc in
				self.flt.bind(enc: enc)
				enc.setFrontFacing(.counterClockwise)
				enc.setStates(self.shadepipe, self.shadedepth, cull: .front)
				enc.setDepthBias(0.001, slopeScale: 0.01, clamp: 0.02)
//				enc.setDepthBias(0.1, slopeScale: 1, clamp: 0.02)
				enc.setVertexAmplificationCount(Renderer.nshd, viewMappings: nil)
				self.drawScene(enc: enc, useprops: false)
			}
		}
		
		self.cmdque.commit(label: "light & drawable") {buf in
			buf.addCompletedHandler {_ in self.semaphore.signal()}
			buf.pass(label: "light", descr: self.lightpass) {enc in
				self.flt.bind(enc: enc)
				enc.setStencilReferenceValue(128)
				enc.setFrontFacing(.counterClockwise)
				
				enc.setStates(self.gbufpipe, self.gbufdepth, cull: .back)
				self.drawScene(enc: enc, useprops: true)
				
				enc.setFragmentTexture(self.shadepass.depthAttachment.texture!, index: 0)
				enc.setStates( self.quadpipe, self.quaddepth, cull: .front)
				enc.draw(mesh: self.quadmesh, iid: 0, nid: 1)
				if self.scene.lgts.count <= 1 {return}
				
				enc.setStates( self.maskpipe, self.maskdepth, cull: .none)
				enc.draw(mesh: self.icosmesh, iid: 1, nid: self.scene.lgts.count-1)
				enc.setStates( self.icospipe, self.icosdepth, cull: .front)
				enc.draw(mesh: self.icosmesh, iid: 1, nid: self.scene.lgts.count-1)
				
			}
			buf.present(view.currentDrawable!)
		}
		
	}
	
	
	private func setProps(enc: MTLRenderCommandEncoder, _ props: Model.Props) {
		enc.setFragmentTexture(props.alb, index: 1)
		enc.setFragmentTexture(props.nml, index: 2)
		enc.setFragmentTexture(props.rgh, index: 3)
		enc.setFragmentTexture(props.mtl, index: 4)
		enc.setFragmentTexture(props.ao, index: 5)
	}
	private func drawScene(enc: MTLRenderCommandEncoder, useprops: Bool) {
		for model in self.scene.models.values {
			if useprops {self.setProps(enc: enc, model.props)}
			for mesh in model.meshes {
				enc.draw(mesh: mesh, iid: model.iid, nid: model.nid)
			}
		}
	}
	
}
