#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "unifs.h"


struct sfrg {
	float4 loc [[position]];
	uint lid [[render_target_array_index]];
};

struct spix {
	float2 mmts [[raster_order_group(0), color(0)]];
};

vertex sfrg vtx_shade(const device mvtx *vtcs	[[buffer(0)]],
					  const device model *mdls	[[buffer(1)]],
					  constant light *lgts		[[buffer(3)]],
					  constant uint &lid		[[buffer(4)]],
					  uint vid					[[vertex_id]],
					  uint iid					[[instance_id]]) {
	model mdl = mdls[iid];
	light lgt = lgts[lid];
	float4 pos = mmul4(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj, lgtbwd(lgt, pos.xyz), pos.w);
	return {.loc = loc, .lid = lid};
}

fragment spix frg_shade(float4 loc [[position]]) {
	float z = loc.z;
	float dx = dfdx(z);
	float dy = dfdy(z);
	return {float2(z, z*z + 0.25*(dx*dx + dy*dy))};
}
