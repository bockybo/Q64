#import <metal_stdlib>
using namespace metal;

#import "geometry.h"
#import "util.h"


vertex geo vtx_main(const device xmvtx *vtcs		[[buffer(0)]],
					const device xmodel *mdls		[[buffer(1)]],
					constant xscene &scn			[[buffer(2)]],
					uint vid						[[vertex_id]],
					uint iid						[[instance_id]]) {
	xmvtx v = vtcs[vid];
	xmodel mdl = mdls[iid];
	float4x4 inv = transpose(mdl.inv);
	geo g = {.tex = v.tex, .mat = mdl.mat};
	g.scr = scrpos(scn.cam, g.pos = mmul3(mdl.ctm, v.pos));
	g.nml = normalize(mmul3(inv, (float3)v.nml, 0.f));
	g.tgt = normalize(mmul3(inv, (float3)v.tgt.xyz, 0.f));
	g.btg = normalize(cross(g.nml, g.tgt) * v.tgt.w);
	return g;
}
