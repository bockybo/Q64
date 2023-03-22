#include <metal_stdlib>
using namespace metal;

#include "config.h"
#include "util.h"
#include "types.h"
#include "unifs.h"
#include "lighting.h"


static inline half4 fwdx_lighting(mfrg f,
								  constant materialbuf &materials,
								  constant scene &scn,
								  constant light *lgts,
								  shadowmaps shds,
								  uint msk) {
#if DEBUG_CULL
	return half4(debug_cull(msk), 1.f);
#endif
	material mat = materialsmp(f, materials);
	float3 pos = f.pos;
	float3 eye = eyedir(scn.cam, pos);
	half3 rgb = 0.h;
	for (int i = 0; (i += ctz(msk >> i)) < 32; ++i)
		rgb += com_lighting(mat, pos, eye, lgts, shds, i);
	return half4(rgb, 1.h);
}

vertex float4 vtxfwdp_depth(const device mvtx *vtcs		[[buffer(0)]],
							const device model *mdls	[[buffer(1)]],
							constant scene &scn			[[buffer(2)]],
							uint vid					[[vertex_id]],
							uint iid					[[instance_id]]) {
	float3 pos = mmul3(mdls[iid].ctm, float4(vtcs[vid].pos, 1.f));
	float4 loc = scrpos(scn.cam, pos);
	return loc;
}

fragment dpix frgfwdp_depth(float4 loc [[position]]) {return {loc.z};}

fragment cpix frgfwdc_light(mfrg f								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return {fwdx_lighting(f, materials, scn, lgts, shds, mskc(scn.nlgt))};
}
fragment cpix frgfwdp_light(mfrg f								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							threadgroup tile &tile				[[threadgroup(0)]],
							shadowmaps shds						[[texture(0)]]) {
	return {fwdx_lighting(f, materials, scn, lgts, shds, mskp(tile))};
}
