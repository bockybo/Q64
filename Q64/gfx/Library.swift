import MetalKit


class lib {
	static let device = MTLCreateSystemDefaultDevice()!
	static let deflib = lib.device.makeDefaultLibrary()!
	static let texldr = MTKTextureLoader(device: lib.device)
	static let meshalloc = MTKMeshBufferAllocator(device: lib.device)
	
	struct shaders {
		
		static let vtx_shade	= util.shader("vtx_shade")
		static let vtx_depth	= util.shader("vtx_depth")
		static let vtx_main		= util.shader("vtx_main")
		static let vtx_quad		= util.shader("vtx_quad")
//		static let vtx_cone		= util.shader("vtx_cone")
//		static let vtx_icos		= util.shader("vtx_icos")
		static let vtx_volume	= util.shader("vtx_volume")
		
		static let frg_gbuf		= util.shader("frg_gbuf")
//		static let frg_quad		= util.shader("frg_quad")
//		static let frg_cone		= util.shader("frg_cone")
//		static let frg_icos		= util.shader("frg_icos")
		static let frg_accum	= util.shader("frg_accum")
		static let frg_fwd		= util.shader("frg_fwd")
		static let frg_depth	= util.shader("frg_depth")
		static let frg_light	= util.shader("frg_light")
		
		static let knl_cull		= util.shader("knl_cull")
		
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
		
		static let psshade = util.pipestate(label: "ps shade") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_shade
			descr.depthAttachmentPixelFormat 		= Renderer.fmt_shade
			descr.inputPrimitiveTopology			= .triangle
			descr.rasterSampleCount = 1
		}
		static let psgbuf = util.pipestate(label: "ps gbuffer") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frg_gbuf
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		
		static let psquad = util.pipestate(label: "ps lighting quad") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_quad
			descr.fragmentFunction					= lib.shaders.frg_accum
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		static let psvolume = util.pipestate(label: "ps lighting volume") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_volume
			descr.fragmentFunction					= lib.shaders.frg_accum
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		
		static let psfwd = util.pipestate(label: "ps lighting forward") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frg_fwd
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
		}
		
		static let dsshade = util.depthstate(label: "ds shade") {
			descr in
			descr.isDepthWriteEnabled 							= true
			descr.depthCompareFunction 							= .lessEqual
		}
		static let dsgbuf = util.depthstate(label: "ds gbuffer") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction 							= .lessEqual
			descr.frontFaceStencil.depthStencilPassOperation	= .replace
			descr.backFaceStencil.depthStencilPassOperation		= .replace
		}
		static let dsquad = util.depthstate(label: "ds lighting quad") {
			descr in
			descr.frontFaceStencil.stencilCompareFunction		= .equal
			descr.backFaceStencil.stencilCompareFunction		= .equal
		}
		static let dsvolume = util.depthstate(label: "ds lighting volume") {
			descr in
			descr.depthCompareFunction							= .greaterEqual
		}
		
		static let dsfwd = util.depthstate(label: "ds lighting forward") {
			descr in
			descr.isDepthWriteEnabled							= true
			descr.depthCompareFunction							= .less
		}
		
		static let psdepth = util.pipestate(label: "ps depth") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_depth
			descr.fragmentFunction					= lib.shaders.frg_depth
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= .r32Float
		}
		static let pscull = util.tilestate(label: "ps cull") {
			descr in
			descr.tileFunction						= lib.shaders.knl_cull
			descr.rasterSampleCount					= 1
			descr.threadgroupSizeMatchesTileSize	= true
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= .r32Float
		}
		static let pslight = util.pipestate(label: "ps light") {
			descr in
			descr.vertexFunction					= lib.shaders.vtx_main
			descr.fragmentFunction					= lib.shaders.frg_light
			descr.depthAttachmentPixelFormat		= Renderer.fmt_depth
			descr.stencilAttachmentPixelFormat		= Renderer.fmt_depth
			descr.colorAttachments[0].pixelFormat	= Renderer.fmt_color
			descr.colorAttachments[1].pixelFormat	= .r32Float
		}
		
		static let dsdepth = util.depthstate(label: "ds depth") {
			descr in
			descr.isDepthWriteEnabled				= true
			descr.depthCompareFunction				= .less
		}
		static let dslight = util.depthstate(label: "ds light") {
			descr in
			descr.isDepthWriteEnabled				= false
			descr.depthCompareFunction				= .lessEqual
		}
		
	}
	
}
