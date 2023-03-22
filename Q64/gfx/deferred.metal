#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "types.h"
#import "unifs.h"
#import "com_lighting.h"


struct gbuf {
	float dep [[raster_order_group(1), color(1)]];
	half4 alb [[raster_order_group(1), color(2)]];
	half4 nml [[raster_order_group(1), color(3)]];
	half4 mat [[raster_order_group(1), color(4)]];
};

fragment gbuf frgbufx_gbuf(mfrg f								[[stage_in]],
						   constant materialbuf &materials		[[buffer(0)]]) {
	material mat = materialsmp(f, materials);
	return {
		.dep = f.loc.z,
		.alb = half4((half3)mat.alb, 0.h),
		.nml = half4((half3)mat.nml, 0.h),
		.mat = half4(mat.rgh, mat.mtl, mat.ao, 0.h),
	};
}

vertex lfrg vtxbufx_quad(const device pvtx *vtcs	[[buffer(0)]],
						 uint vid					[[vertex_id]],
						 uint lid					[[instance_id]]) {
	return {.loc = float4(vtcs[vid], 1.f), .lid = lid};
}
vertex lfrg vtxbufx_vol(const device pvtx *vtcs 	[[buffer(0)]],
						constant scene &scn			[[buffer(2)]],
						constant light *lgts		[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint lid					[[instance_id]]) {
	float3 pos = lgtfwd(lgts[lid], vtcs[vid]);
	float4 loc = scrpos(scn.cam, pos);
	return {.loc = loc, .lid = lid};
}

inline half4 bufx_lighting(lfrg f,
						   const gbuf buf,
						   constant scene &scn,
						   constant light *lgts,
						   shadowmaps shds,
						   uint msk) {
#if DEBUG_CULL
	return half4(debug_cull(msk), 1.f);
#endif
	if (!(msk & (1 << f.lid)))
		return {0.h};
	material mat = {
		.alb = (float3)buf.alb.rgb,
		.nml = (float3)buf.nml.xyz,
		.rgh = (float) buf.mat.r,
		.mtl = (float) buf.mat.g,
		. ao = (float) buf.mat.b,
	};;
	float2 ndc = loc2ndc(f.loc.xy/(float2)scn.cam.res);
	float3 pos = wldpos(scn.cam, float3(ndc, buf.dep));
	float3 eye = eyedir(scn.cam, pos);
	half3 rgb = com_lighting(mat, pos, eye, lgts, shds, f.lid);
	
	return half4(rgb, 1.h);
}

fragment cpix frgbufc_light(lfrg f								[[stage_in]],
							const cpix pix,
							const gbuf buf,
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return {pix.color + bufx_lighting(f, buf, scn, lgts, shds, mskc(scn.nlgt))};
}
fragment cpix frgbufp_light(lfrg f								[[stage_in]],
							const cpix pix,
							const gbuf buf,
							threadgroup tile &tile				[[threadgroup(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return {pix.color + bufx_lighting(f, buf, scn, lgts, shds, mskp(tile))};
}
