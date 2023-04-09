#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "culling.h"
#import "lighting.h"
#import "lighting_model.h"


inline float shadowcmp(float cmp, float2 mmts) {
	return cmp <= mmts.x;
}
//inline float shadowcmp(float cmp, float2 mmts) {
//	constexpr float pmin = SHD_PMIN;
//	constexpr float pmax = SHD_PMAX;
//	float v = mmts.y - mmts.x*mmts.x;
//	float d = cmp - mmts.x;
//	float p = v / (v + d*d);
//	return (d <= 0.f)? 1.f : saturate(lin(pmin, pmax, p));
//}
inline float2 shadowsmp(shadowmaps shds, uint sid, float2 loc) {
	constexpr sampler smp(filter::linear);
	constexpr int n = SHD_NPCF;
	float2 mmts = 0.f;
	for (int i = 0; i < n*n; ++i)
		mmts += shds.sample(smp, loc, sid, int2(i/n, i%n) - n/2).xy;
	return mmts / (float)(n*n);
}
inline float shadow(shadowmaps shds, uint sid, xlight lgt, float3 pos) {
	float3 ndc = mmulw(lgt.proj, pos);
	return shadowcmp(ndc.z, shadowsmp(shds, sid, ndc2loc(ndc.xy)));
}

float3 bdrf(xmaterial mat, float3 l, float3 v) {
	
	float3 n = normalize(mat.nml);
	float3 h = normalize(l + v);
	float ndl = max(0.f, dot(n, l));
	float ndv = max(0.f, dot(n, v));
	float ndh = max(0.f, dot(n, h));
	float ldh = max(0.f, dot(l, h));

	float3 fd = mat.alb;
	float3 fs = BASE_F0;

	fs = mix(fs, mat.alb, mat.mtl);
	fs = FS(fs, ldh);
	
	fd = mix(fd, 0.f, mat.mtl);
	fd = mix(fd, 0.f, fs);
	fd = FD(fd, ldh, ndl, ndv, mat.rgh);

	fs *= NDF(mat.rgh, ndh);
	fs *= GSF(mat.rgh, max(1e-5f, ndl));
	fs *= GSF(mat.rgh, max(1e-5f, ndv));
	fs /= 4.f * max(1e-5f, ndl) * max(1e-5f, ndv);

	return saturate(ndl * (fd + fs));
	
}

// xyz: normalized direction, w: attenuation
typedef float4 (*attenuator)(float3 wld,
							 xscene scn,
							 xlight lgt,
							 shadowmaps shds,
							 uint lid);
float4 qatt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmaps shds,
			uint lid) {
	float3 dir = lgt.dir;
	float  att = shadow(shds, lid, lgt, direct(wld, dir));
	return float4(dir, att);
}
float4 iatt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmaps shds,
			uint lid) {
	float3 dlt = wld - lgt.pos;
	float3 dir = normalize(dlt);
	float rad = length(dlt);
	float att = max(0.f, 1.f - rad/lgt.rad);
	short amp = faceof(-dlt);
	uint sid = sid6(scn, lid, amp);
	att *= shadow(shds, sid, lgt, reface(dlt, amp));
	return float4(dir, att);
}
float4 catt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmaps shds,
			uint lid) {
	float3 dlt = wld - lgt.pos;
	float3 dir = normalize(dlt);
	float rad = length(dlt);
	float phi = angle90(dir, lgt.dir);
	float att = 1.f;
	att *= max(0.f, 1.f - rad/lgt.rad);
	att *= max(0.f, 1.f - phi/lgt.phi);
	att *= shadow(shds, lid, lgt, direct(dlt, lgt.dir));
	return float4(dir, att);
}

inline float3 debug_mask(float3 rgb, xlight lgt) {
	return rgb + normalize(lgt.hue)*0.2f;
}
inline float3 debug_cull(float3 rgb, xlight lgt) {
	constexpr float3 a = float3(0.00f, 0.10f, 0.25f);
	constexpr float3 b = float3(1.00f, 0.25f, 0.00f);
	if (is_qlight(lgt))
		return 0.05f;
	else if (all(rgb <= 0.05f))
		return rgb + a;
	else
		return rgb + (b - a)/MAX_NLIGHT;
}
float3 comx_lighting(float3 rgb,
					 float3 wld,
					 xmaterial mat,
					 constant xscene &scn,
					 constant xlight *lgts,
					 shadowmaps shds,
					 uint lid) {
	constexpr attenuator attfns[3] = {qatt, iatt, catt};
	xlight lgt = lgts[lid];
#if DEBUG_MASK
	return debug_mask(rgb, lgt);
#endif
#if DEBUG_CULL
	return debug_cull(rgb, lgt);
#endif
	float3 eye = normalize(viewpos(scn.cam.view) - wld);
	float4 att = attfns[light_type(lgt)](wld, scn, lgt, shds, lid);
	return rgb + att.w * lgt.hue * bdrf(mat, -att.xyz, eye);
}
