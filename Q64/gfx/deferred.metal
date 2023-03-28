#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "material.h"
#import "lighting.h"


struct gbuf {
	float dep [[raster_order_group(1), color(1)]];
	half4 alb [[raster_order_group(1), color(2)]];
	half4 nml [[raster_order_group(1), color(3)]];
	half2 mat [[raster_order_group(1), color(4)]];
};

struct lfrg {
	float4 loc [[position]];
	uint lid [[flat]];
};

fragment gbuf frgbufx_gbuf(geo g							[[stage_in]],
						   constant materialbuf &materials	[[buffer(0)]]) {
	xmaterial mat = materialsmp(g, materials);
	return {
		.dep = g.loc.z,
		.alb = half4((half3)mat.alb, 0.h),
		.nml = half4((half3)mat.nml, 0.h),
		.mat = half2(mat.rgh, mat.mtl),
	};
}

vertex lfrg vtxbufx_quad(const device xpvtx *vtcs	[[buffer(0)]],
						 uint vid					[[vertex_id]],
						 uint lid					[[instance_id]]) {
	return {.loc = float4(vtcs[vid], 1.f), .lid = lid};
}
vertex lfrg vtxbufx_vol(const device xpvtx *vtcs 	[[buffer(0)]],
						constant xscene &scn		[[buffer(2)]],
						constant xlight *lgts		[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint lid					[[instance_id]]) {
	xlight lgt = lgts[lid];
	float3 pos = vtcs[vid];
	pos *= lgt.rad;
	pos += lgt.pos;
	float4 loc = scrpos(scn.cam, pos);
	return {.loc = loc, .lid = lid};
}

inline cpix bufx_lighting(lfrg f,
						  const cpix pix,
						  const gbuf buf,
						  constant xscene &scn,
						  constant xlight *lgts,
						  texture2d_array<float> shds,
						  uint msk) {
	if (!(msk & (1 << f.lid)))
		return pix;
	xmaterial mat = {
		.alb = (float3)buf.alb.rgb,
		.nml = (float3)buf.nml.xyz,
		.rgh = (float) buf.mat.r,
		.mtl = (float) buf.mat.g,
	};
	float2 ndc = loc2ndc(f.loc.xy/(float2)scn.cam.res);
	float3 wld = wldpos(scn.cam, float3(ndc, buf.dep));
	float3 rgb = (float3)pix.color.rgb;
	rgb = com_lighting(rgb, wld, mat, scn, lgts, {shds, f.lid});
	return {half4((half3)rgb, 1.h)};
}

fragment cpix frgbufc_light(lfrg f								[[stage_in]],
							const cpix pix,
							const gbuf buf,
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							texture2d_array<float> shds			[[texture(0)]]) {
	return bufx_lighting(f, pix, buf, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgbufp_light(lfrg f								[[stage_in]],
							const cpix pix,
							const gbuf buf,
							threadgroup tile &tile				[[threadgroup(0)]],
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							texture2d_array<float> shds			[[texture(0)]]) {
	return bufx_lighting(f, pix, buf, scn, lgts, shds, mskp(tile));
}
