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
	float4 scr [[position]];
	uint lid [[flat]];
};

fragment gbuf frgbufx_gbuf(geo g							[[stage_in]],
						   constant materialbuf &materials	[[buffer(0)]]) {
	xmaterial mat = materialsmp(g, materials);
	return {
		.dep = g.scr.z,
		.alb = half4((half3)mat.alb, 0.h),
		.nml = half4((half3)mat.nml, 0.h),
		.mat = half2(mat.rgh, mat.mtl),
	};
}

vertex lfrg vtxbufx_quad(uint vid					[[vertex_id]],
						 uint lid					[[instance_id]]) {
	constexpr float2 vtcs[6] = {
		float2(+1.f, -1.f), float2(-1.f, -1.f), float2(-1.f, +1.f),
		float2(+1.f, -1.f), float2(-1.f, +1.f), float2(+1.f, +1.f)};
	return {.scr = float4(vtcs[vid], 0.f, 1.f), .lid = lid};
}

vertex lfrg vtxbufx_icos(const device pvtx *vtcs 	[[buffer(0)]],
						 constant xscene &scn		[[buffer(2)]],
						 constant xlight *lgts		[[buffer(3)]],
						 uint vid					[[vertex_id]],
						 uint lid					[[instance_id]]) {
	xlight lgt = lgts[lid];
	float3 pos = vtcs[vid];
	pos *= lgt.rad;
	pos += lgt.pos;
	return {.scr = wld2scr(scn.cam, pos), .lid = lid};
}

inline cpix bufx_lighting(lfrg f,
						  cpix pix,
						  gbuf buf,
						  constant xscene &scn,
						  constant xlight *lgts,
						  shadowmaps shds,
						  uint bin) {
	if (!(bin & (1 << f.lid)))
		return pix;
	xmaterial mat = {
		.alb = (float3)buf.alb.rgb,
		.nml = (float3)buf.nml.xyz,
		.rgh = (float) buf.mat.r,
		.mtl = (float) buf.mat.g,
	};
	float3 wld = scr2wld(scn.cam, f.scr.xy, buf.dep);
	float3 rgb = (float3)pix.color.rgb;
	rgb = comx_lighting(rgb, wld, mat, scn, lgts, shds, f.lid);
	return {half4((half3)rgb, 1.h)};
}

fragment cpix frgbuf0_light(lfrg f						[[stage_in]],
							cpix pix,
							gbuf buf,
							constant xscene &scn		[[buffer(2)]],
							constant xlight *lgts		[[buffer(3)]],
							shadowmaps shds				[[texture(0)]]) {
	return bufx_lighting(f, pix, buf, scn, lgts, shds, ldbin(scn.nlgt));
}
fragment cpix frgbufp_light(lfrg f						[[stage_in]],
							cpix pix,
							gbuf buf,
							threadgroup visbin &bin		[[threadgroup(0)]],
							constant xscene &scn		[[buffer(2)]],
							constant xlight *lgts		[[buffer(3)]],
							shadowmaps shds				[[texture(0)]]) {
	return bufx_lighting(f, pix, buf, scn, lgts, shds, ldbin(bin));
}
fragment cpix frgbufc_light(lfrg f						[[stage_in]],
							cpix pix,
							gbuf buf,
							threadgroup visbin *bins	[[threadgroup(0)]],
							constant xscene &scn		[[buffer(2)]],
							constant xlight *lgts		[[buffer(3)]],
							shadowmaps shds				[[texture(0)]]) {
	return bufx_lighting(f, pix, buf, scn, lgts, shds, ldbin(bins, scn.cam, buf.dep));
}


