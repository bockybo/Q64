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
//	return (d <= 0.f)? 1.f : saturate(unmix(pmin, pmax, p));
//}
inline float2 shadowsmp(shadowmap shd, uint sid, float2 loc) {
	constexpr sampler smp(filter::linear);
	constexpr int n = SHD_NPCF;
	float2 mmts = 0.f;
	for (int x = 0; x < n; ++x)
		for (int y = 0; y < n; ++y)
			mmts += shd.sample(smp, loc, sid, int2(x, y)-n/2).xy;
	return mmts / (float)(n*n);
}
inline float shadow(shadowmap shd, uint sid, xlight lgt, float3 pos) {
	float3 ndc = mmulw(lgt.proj, pos);
	return shadowcmp(ndc.z, shadowsmp(shd, sid, ndc2loc(ndc.xy)));
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

inline float3 debug_mask(float3 rgb, xlight lgt) {
	return rgb + normalize(lgt.hue)*0.2f;
}
inline float3 debug_cull(float3 rgb) {
	constexpr float3 a = float3(0.00f, 0.10f, 0.25f);
	constexpr float3 b = float3(1.00f, 0.25f, 0.00f);
	return all(rgb == 0.f)? a : rgb + (b - a)/32.f;
}

// xyz: normalized direction, w: attenuation
typedef float4 (*attenuator)(float3 wld,
							 xscene scn,
							 xlight lgt,
							 shadowmap shd,
							 uint lid);
float4 qatt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmap shd,
			uint lid) {
	float3 dir = lgt.dir;
	float  att = shadow(shd, lid, lgt, direct(wld, dir));
	return float4(dir, att);
}
float4 iatt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmap shd,
			uint lid) {
	float3 dlt = wld - lgt.pos;
	float3 dir = normalize(dlt);
	float rad = length(dlt);
	float att = max(0.f, 1.f - rad/lgt.rad);
	short amp = faceof(-dlt);
	uint sid = sid6(scn, lid, amp);
	att *= shadow(shd, sid, lgt, reface(dlt, amp));
	return float4(dir, att);
}
float4 catt(float3 wld,
			xscene scn,
			xlight lgt,
			shadowmap shd,
			uint lid) {
	float3 dlt = wld - lgt.pos;
	float3 dir = normalize(dlt);
	float rad = length(dlt);
	float phi = angle90(dir, lgt.dir);
	float att = 1.f;
	att *= max(0.f, 1.f - rad/lgt.rad);
	att *= max(0.f, 1.f - phi/lgt.phi);
	att *= shadow(shd, lid, lgt, direct(dlt, lgt.dir));
	return float4(dir, att);
}

float3 comx_lighting(float3 rgb,
					 float3 wld,
					 xmaterial mat,
					 constant xscene &scn,
					 constant xlight *lgts,
					 shadowmap shd,
					 uint lid) {
	constexpr attenuator attfns[3] = {qatt, iatt, catt};
	xlight lgt = lgts[lid];
#if DEBUG_CULL
	return debug_cull(rgb);
#endif
#if DEBUG_MASK
	return debug_mask(rgb, lgt);
#endif
	float4 a = attfns[light_type(lgt)](wld, scn, lgt, shd, lid);
	float3 dir = a.xyz;
	float  att = a.w;
	rgb += att * lgt.hue * bdrf(mat, -dir, eyedir(scn.cam, wld));
	return rgb;
}
