#include <metal_stdlib>
using namespace metal;

#include "util.h"
#include "types.h"
#include "unifs.h"


vertex float4 vtx_shade(const device mvtx *vtcs		[[buffer(0)]],
						const device model *mdls	[[buffer(1)]],
						constant light &lgt			[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	model mdl = mdls[iid];
	float4 pos = mmul4(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj, lgtbwd(lgt, pos.xyz), pos.w);
	return loc;
}

fragment spix frg_shade(float4 loc [[position]]) {
	float z = loc.z;
	float dx = dfdx(z);
	float dy = dfdy(z);
	return {float2(z, z*z + 0.25*(dx*dx + dy*dy))};
}
