#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "culling.h"
#import "lighting.h"
#import "lighting_model.h"


float2 shadowmap::sample(float2 loc, int2 off) {
	return map.sample(smp, loc, i, off).xy;
}

inline float shadowcmp(float cmp, float2 mmts) {
	return cmp <= mmts.x;
}
//inline float shadowcmp(float cmp, float2 mmts) {
//	constexpr float pmin = SHD_PMIN;
//	constexpr float pmax = SHD_PMAX;
//	float v = abs(mmts.y - mmts.x*mmts.x);
//	float d = cmp - mmts.x;
//	float p = v / (v + d*d);
//	return (d <= 0.f)? 1.f : saturate(unmix(pmin, pmax, p));
//}

//inline float shadowsmp(shadowmap shd, float2 loc, float cmp) {
//	return shadowcmp(cmp, shd.sample(loc));
//}
//inline float shadowsmp(shadowmap shd, float2 loc, float cmp) {
//	constexpr int n = SHD_NPCF;
//	float2 mmts = 0.f;
//	for (int x = 0; x < n; ++x)
//		for (int y = 0; y < n; ++y)
//			mmts += shd.sample(loc, int2(x, y)-n/2);
//	return shadowcmp(cmp, mmts / (float)(n*n));
//}
inline float shadowsmp(shadowmap shd, float2 loc, float cmp) {
	constexpr float spr = 7e-4f;
	constexpr float2 offs[4] = {
		float2(-0.942016240, -0.39906216),
		float2( 0.945586090, -0.76890725),
		float2(-0.094184101, -0.92938870),
		float2( 0.344959380,  0.29387760),
	};
	float2 mmts = 0.f;
	for (int i = 0; i < 4; ++i)
		mmts += shd.sample(loc + offs[i]*spr);
	return shadowcmp(cmp, mmts * 0.25f);
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

inline float3 debug_mask(xlight lgt) {
	return normalize(lgt.hue) * 0.2h;
}
inline float3 debug_cull(float3 rgb) {
	constexpr float3 a = float3(0.00f, 0.10f, 0.25f);
	constexpr float3 b = float3(1.00f, 0.25f, 0.00f);
	return all(rgb == 0.h)? a : rgb + (b - a)/32.h;
}

// TODO: loop til scene counts for light types, rather than dispatch
float3 comx_lighting(float3 rgb,
					 float3 wld,
					 xmaterial mat,
					 constant xscene &scn,
					 constant xlight *lgts,
					 shadowmap shd) {
	xlight lgt = lgts[shd.i];
#if DEBUG_CULL
	return debug_cull(rgb);
#endif
#if DEBUG_MASK
	return debug_mask(lgt);
#endif
	float att = 1.f;
	float3 dir;
	float3 pos;
	if (is_qlight(lgt)) {
		dir = -lgt.dir;
		pos = lgtpos(lgt, wld);
	} else {
		float3 dlt = lgt.pos - wld;
		float rad = length(dlt);
		att *= max(0.f, 1.f - rad/lgt.rad);
		dir = normalize(dlt);
		if (is_clight(lgt)) {
			float phi = angle90(lgt.dir, -dir);
			att *= max(0.f, 1.f - phi/lgt.phi);
			pos = lgtpos(lgt, wld);
		} else {
			short amp = faceof(dlt);
			shd.i = sid6(scn, shd.i, amp);
			pos = lgtpos(lgt, wld, amp);
		}
	}
	if (att > 0.f) {
		float3 eye = eyedir(scn.cam, wld);
		float3 ndc = mmulw(lgt.proj, pos);
		att *= shadowsmp(shd, ndc2loc(ndc.xy), ndc.z);
		rgb += att * lgt.hue * bdrf(mat, dir, eye);
	}
	return saturate(rgb);

}
