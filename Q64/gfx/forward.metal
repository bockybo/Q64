#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "material.h"
#import "lighting.h"


inline half4 fwdx_lighting(geo g,
						   constant materialbuf &materials,
						   constant xscene &scn,
						   constant xlight *lgts,
						   shadowmaps shds,
						   uint msk) {
#if DEBUG_CULL
	return half4(debug_cull(msk), 1.f);
#endif
	xmaterial mat = materialsmp(g, materials);
	float3 pos = g.pos;
	float3 eye = eyedir(scn.cam, pos);
	half3 rgb = 0.h;
	for (int i = 0; (i += ctz(msk >> i)) < 32; ++i)
		rgb += com_lighting(mat, pos, eye, lgts, shds, i);
	return half4(rgb, 1.h);
}

vertex float4 vtxfwdp_depth(const device xmvtx *vtcs	[[buffer(0)]],
							const device xmodel *mdls	[[buffer(1)]],
							constant xscene &scn		[[buffer(2)]],
							uint vid					[[vertex_id]],
							uint iid					[[instance_id]]) {
	float3 pos = mmul3(mdls[iid].ctm, float4(vtcs[vid].pos, 1.f));
	float4 loc = scrpos(scn.cam, pos);
	return loc;
}

fragment dpix frgfwdp_depth(float4 loc [[position]]) {return {loc.z};}

fragment cpix frgfwdc_light(geo g								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return {fwdx_lighting(g, materials, scn, lgts, shds, mskc(scn.nlgt))};
}
fragment cpix frgfwdp_light(geo	g								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							threadgroup tile &tile				[[threadgroup(0)]],
							shadowmaps shds						[[texture(0)]]) {
	return {fwdx_lighting(g, materials, scn, lgts, shds, mskp(tile))};
}
