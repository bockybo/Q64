#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "material.h"
#import "lighting.h"


vertex float4 vtxfwdp_depth(const device xmvtx *vtcs	[[buffer(0)]],
							const device xmodel *mdls	[[buffer(1)]],
							constant xscene &scn		[[buffer(2)]],
							uint vid					[[vertex_id]],
							uint iid					[[instance_id]]) {
	float3 pos = mmul3(mdls[iid].ctm, vtcs[vid].pos);
	return scrpos(scn.cam, pos);
}
fragment dpix frgfwdp_depth(float4 scr [[position]]) {return {scr.z};}

inline cpix fwdx_lighting(geo g,
						  constant materialbuf &materials,
						  constant xscene &scn,
						  constant xlight *lgts,
						  shadowmap shds,
						  uint msk) {
	xmaterial mat = materialsmp(g, materials);
	float3 wld = g.pos;
	float3 rgb = 0.f;
	for (uint i = 0; (i += ctz(msk >> i)) < scn.nlgt; ++i)
		rgb = comx_lighting(rgb, wld, mat, scn, lgts, shds, i);
	return {half4((half3)rgb, 1.h)};
}
fragment cpix frgfwdc_light(geo g								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							shadowmap shds						[[texture(0)]]) {
	return fwdx_lighting(g, materials, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgfwdp_light(geo	g								[[stage_in]],
							threadgroup tile &tile				[[threadgroup(0)]],
							constant materialbuf &materials		[[buffer(0)]],
							constant xscene &scn				[[buffer(2)]],
							constant xlight *lgts				[[buffer(3)]],
							shadowmap shds						[[texture(0)]]) {
	return fwdx_lighting(g, materials, scn, lgts, shds, mskp(tile));
}
