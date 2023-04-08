import MetalKit


class lib {
	
	static let device = MTLCreateSystemDefaultDevice()!
	static let deflib = lib.device.makeDefaultLibrary()!
	static let texldr = MTKTextureLoader(device: lib.device)
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	struct shaders {
		
		static let vtx_main			= util.shader("vtx_main")
		
		static let vtx_shade1		= util.shader("vtx_shade1")
		static let vtx_shade6		= util.shader("vtx_shade6")
		static let frg_shade		= util.shader("frg_shade")
		
		static let knl_cull2d		= util.shader("knl_cull2d")
		static let knl_cull3d		= util.shader("knl_cull3d")
		
		static let vtxfwdp_depth	= util.shader("vtxfwdp_depth")
		static let frgfwdp_depth	= util.shader("frgfwdp_depth")
		static let frgfwd0_light	= util.shader("frgfwd0_light")
		static let frgfwdp_light	= util.shader("frgfwdp_light")
		static let frgfwdc_light	= util.shader("frgfwdc_light")
		
		static let vtxbufx_quad		= util.shader("vtxbufx_quad")
		static let vtxbufx_icos		= util.shader("vtxbufx_icos")
		static let frgbufx_gbuf		= util.shader("frgbufx_gbuf")
		static let frgbuf0_light	= util.shader("frgbuf0_light")
		static let frgbufp_light	= util.shader("frgbufp_light")
		static let frgbufc_light	= util.shader("frgbufc_light")
		
	}
	
	struct vtxdescrs {
		
		static let base = util.vtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
		])
		
		static let main = util.vtxdescr([
			(fmt: .float3, name: MDLVertexAttributePosition),
			(fmt: .float3, name: MDLVertexAttributeNormal),
			(fmt: .float4, name: MDLVertexAttributeTangent),
			(fmt: .float2, name: MDLVertexAttributeTextureCoordinate)
		])
		
	}
	
	struct pstates {
		
		static let shade1 = util.pipestate(label: "ps shade2d") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_shade1
			descr.fragmentFunction					= lib.shaders.frg_shade
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_shade
			descr.depthAttachmentPixelFormat 		= Renderer.fmt_depth
			descr.inputPrimitiveTopology			= .triangle
		}
		static let shade6 = util.pipestate(label: "ps shade3d") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_shade6
			descr.fragmentFunction					= lib.shaders.frg_shade
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_shade
			descr.depthAttachmentPixelFormat 		= Renderer.fmt_depth
			descr.inputPrimitiveTopology			= .triangle
			descr.maxVertexAmplificationCount		= 6
		}
		
		static let fwdp_depth = util.pipestate(label: "ps fwd+ depth prepass") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxfwdp_depth
			descr.fragmentFunction					= lib.shaders.frgfwdp_depth
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
		}
		
		static let fwd0_light = util.pipestate(label: "ps fwd0 lighting") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgfwd0_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		static let fwdp_light = util.pipestate(label: "ps fwd+ lighting") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgfwdp_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
		}
		static let fwdc_light = util.pipestate(label: "ps fwdc lighting") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgfwdc_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		
		static let bufx_gbuf = util.pipestate(label: "ps bufx gbuffer") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgbufx_gbuf
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		static let buf0_quad = util.pipestate(label: "ps buf0 lighting quad") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_quad
			descr.fragmentFunction					= lib.shaders.frgbuf0_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		static let buf0_icos = util.pipestate(label: "ps buf0 lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_icos
			descr.fragmentFunction					= lib.shaders.frgbuf0_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		
		static let bufp_quad = util.pipestate(label: "ps buf+ lighting quad") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_quad
			descr.fragmentFunction					= lib.shaders.frgbufp_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		static let bufp_icos = util.pipestate(label: "ps buf+ lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_icos
			descr.fragmentFunction					= lib.shaders.frgbufp_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		
		static let bufc_quad = util.pipestate(label: "ps bufc lighting quad") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_quad
			descr.fragmentFunction					= lib.shaders.frgbufc_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		static let bufc_icos = util.pipestate(label: "ps bufc lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_icos
			descr.fragmentFunction					= lib.shaders.frgbufc_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		
		static let fwdp_cull = util.tilestate(label: "ps fwd+ light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull2d
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.threadgroupSizeMatchesTileSize	= true
		}
		static let fwdc_cull = util.tilestate(label: "ps fwdc light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull3d
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.threadgroupSizeMatchesTileSize	= true
		}
		static let bufp_cull = util.tilestate(label: "ps buf+ light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull2d
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
			descr.threadgroupSizeMatchesTileSize	= true
		}
		static let bufc_cull = util.tilestate(label: "ps bufc light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull3d
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
			descr.threadgroupSizeMatchesTileSize	= true
		}
		
	}
	
	struct  dstates {
		
		static let shade = util.depthstate(label: "ds shade") {
			descr in
			descr.isDepthWriteEnabled 							= true
			descr.depthCompareFunction 							= .lessEqual
		}
		
		static let prepass = util.depthstate(label: "ds prepass") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .less
			descr.frontFaceStencil.depthStencilPassOperation	= .replace
			descr.backFaceStencil.depthStencilPassOperation		= .replace
		}
		
		static let fwd0_light = util.depthstate(label: "ds fwd0 lighting") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .lessEqual
		}
		static let fwdp_light = util.depthstate(label: "ds fwd+ lighting") {
			descr in
			descr.depthCompareFunction							= .lessEqual
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		static let fwdc_light = util.depthstate(label: "ds fwdc lighting") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .lessEqual
		}
		
		static let bufx_quad = util.depthstate(label: "ds bufx lighting quad") {
			descr in
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		static let bufx_icos = util.depthstate(label: "ds bufx lighting icos") {
			descr in
			descr.depthCompareFunction							= .greaterEqual
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		
	}
	
}
