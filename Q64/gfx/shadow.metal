#import <metal_stdlib>
using namespace metal;

#import "util.h"


struct sfrg {
	float4 loc [[position]];
	uint sid [[render_target_array_index]];
};

struct spix {
	float2 mmts [[raster_order_group(0), color(0)]];
};

vertex sfrg vtx_shade1(const device xmvtx *vtcs		[[buffer(0)]],
					   const device xmodel *mdls	[[buffer(1)]],
					   constant xlight *lgts		[[buffer(3)]],
					   constant uint &lid			[[buffer(4)]],
					   uint vid						[[vertex_id]],
					   uint iid						[[instance_id]]) {
	xmodel mdl = mdls[iid];
	xlight lgt = lgts[lid];
	float3 pos = mmul3(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj, direct(pos - lgt.pos, lgt.dir));
	return {.loc = loc, .sid = lid};
}
vertex sfrg vtx_shade6(const device xmvtx *vtcs		[[buffer(0)]],
					   const device xmodel *mdls	[[buffer(1)]],
					   constant xscene &scn			[[buffer(2)]],
					   constant xlight *lgts		[[buffer(3)]],
					   constant uint &lid			[[buffer(4)]],
					   uint vid						[[vertex_id]],
					   uint iid						[[instance_id]],
					   ushort amp					[[amplification_id]]) {
	xmodel mdl = mdls[iid];
	xlight lgt = lgts[lid];
	float3 pos = mmul3(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj, reface(pos - lgt.pos, amp));
	return {.loc = loc, .sid = sid6(scn, lid, amp)};
}

fragment spix frg_shade(float4 loc [[position]]) {
	float z = loc.z;
	float dx = dfdx(z);
	float dy = dfdy(z);
	float b = (dx*dx + dy*dy) * 0.25f;
	return {float2(z, z*z + b)};
}
