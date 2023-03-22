#include <metal_stdlib>
using namespace metal;

#include "util.h"
#include "types.h"
#include "unifs.h"


vertex mfrg vtx_main(const device mvtx *vtcs		[[buffer(0)]],
					 const device model *mdls		[[buffer(1)]],
					 constant scene &scn			[[buffer(2)]],
					 uint vid						[[vertex_id]],
					 uint iid						[[instance_id]]) {
	mvtx v = vtcs[vid];
	model mdl = mdls[iid];
	float4x4 inv = transpose(mdl.inv);
	mfrg f = {.tex = v.tex, .mat = mdl.mat};
	f.pos = mmul3(mdl.ctm, v.pos);
	f.loc = scrpos(scn.cam, f.pos);
	f.nml = normalize(mmul3(inv, (float3)v.nml, 0.f));
	f.tgt = normalize(mmul3(inv, (float3)v.tgt.xyz, 0.f));
	f.btg = normalize(cross(f.nml, f.tgt) * v.tgt.w);
	return f;
}
