import MetalKit


class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	static let deflib = lib.device.makeDefaultLibrary()!
	static let texldr = MTKTextureLoader(device: lib.device)
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	struct shaders {
		
		static let vtx_main			= util.shader("vtx_main")
		
		static let vtx_shade		= util.shader("vtx_shade")
		static let frg_shade		= util.shader("frg_shade")
		
		static let knl_cull			= util.shader("knl_cull")
		
		static let vtxfwdp_depth	= util.shader("vtxfwdp_depth")
		static let frgfwdp_depth	= util.shader("frgfwdp_depth")
		static let frgfwdc_light	= util.shader("frgfwdc_light")
		static let frgfwdp_light	= util.shader("frgfwdp_light")
		
		static let vtxbufx_quad		= util.shader("vtxbufx_quad")
		static let vtxbufx_vol		= util.shader("vtxbufx_vol")
		static let frgbufx_gbuf		= util.shader("frgbufx_gbuf")
		static let frgbufc_light	= util.shader("frgbufc_light")
		static let frgbufp_light	= util.shader("frgbufp_light")
		
		
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
	
	struct lightmesh {
		static let volumedim = float3(12 / (sqrtf(3) * (3+sqrtf(5))))
		
		static let quad = util.mesh.quad(
			dim: 2 * .xy,
			descr: lib.vtxdescrs.base
		)
		static let icos = util.mesh.icos(
			dim: lib.lightmesh.volumedim,
			descr: lib.vtxdescrs.base
		)
		static let cone = util.mesh.cone(
			dim: lib.lightmesh.volumedim * (1 + .xz),
			seg: uint2(20, 20),
			ctm: .xrot(-.pi/2) * .ypos(-0.5),
			descr: lib.vtxdescrs.base
		) // origin at center not apex, docs lie
		
	}
	
	struct states {
		
		static let psx_shade = util.pipestate(label: "ps shade") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_shade
			descr.fragmentFunction					= lib.shaders.frg_shade
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_shade
			descr.depthAttachmentPixelFormat 		= Renderer.fmt_depth
			descr.rasterSampleCount					= Renderer.shadow_msaa
			descr.inputPrimitiveTopology			= .triangle
		}
		
		static let psfwdc_light = util.pipestate(label: "ps fwd0 lighting") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgfwdc_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		
		static let psfwdp_depth = util.pipestate(label: "ps fwd+ depth prepass") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxfwdp_depth
			descr.fragmentFunction					= lib.shaders.frgfwdp_depth
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
		}
		static let psfwdp_light = util.pipestate(label: "ps fwd+ lighting") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frgfwdp_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
		}
		static let psfwdp_cull = util.tilestate(label: "ps fwd+ light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.threadgroupSizeMatchesTileSize	= true
		}
		
		
		static let psbufx_gbuf = util.pipestate(label: "ps bufx gbuffer") {
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
		
		static let psbufc_quad = util.pipestate(label: "ps buf0 lighting quad") {
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
		static let psbufc_vol = util.pipestate(label: "ps buf0 lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_vol
			descr.fragmentFunction					= lib.shaders.frgbufc_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		
		static let psbufp_quad = util.pipestate(label: "ps buf+ lighting quad") {
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
		static let psbufp_vol = util.pipestate(label: "ps buf+ lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtxbufx_vol
			descr.fragmentFunction					= lib.shaders.frgbufp_light
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
		}
		static let psbufp_cull = util.tilestate(label: "ps buf+ light culling") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= Renderer.fmt_dep
			descr.colorAttachments[2].pixelFormat	= Renderer.fmt_alb
			descr.colorAttachments[3].pixelFormat	= Renderer.fmt_nml
			descr.colorAttachments[4].pixelFormat	= Renderer.fmt_mat
			descr.threadgroupSizeMatchesTileSize	= true
		}
		
		
		static let dsx_shade = util.depthstate(label: "ds shade") {
			descr in
			descr.isDepthWriteEnabled 							= true
			descr.depthCompareFunction 							= .lessEqual
		}
		
		static let dsx_prepass = util.depthstate(label: "ds prepass") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .less
			descr.frontFaceStencil.depthStencilPassOperation	= .replace
			descr.backFaceStencil.depthStencilPassOperation		= .replace
		}
		
		static let dsfwdc_light = util.depthstate(label: "ds fwd0 lighting") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .lessEqual
		}
		static let dsfwdp_light = util.depthstate(label: "ds fwd+ lighting") {
			descr in
			descr.depthCompareFunction							= .lessEqual
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		
		static let dsbufx_quad = util.depthstate(label: "ds bufx lighting quad") {
			descr in
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		static let dsbufx_vol = util.depthstate(label: "ds bufx lighting vol") {
			descr in
			descr.depthCompareFunction							= .greaterEqual
		}
		
	}
	
}
