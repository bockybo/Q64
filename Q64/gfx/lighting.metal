#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "culling.h"
#import "lighting.h"
#import "lighting_model.h"


inline half3 debug_mask(xlight lgt) {
	return (half3)normalize(lgt.hue) * 0.2h;
}
inline half3 debug_cull(uint msk) {
	constexpr half3 a = half3( 16,  16,  32);
	constexpr half3 b = half3(256, 128,   0);
	half x = (half)popcount(msk) / 32.h;
	return mix(a, b, x)/256.h;
}


inline float shadowcmp(float cmp, float2 mmts) {
	constexpr float vmin = SHD_VMIN;
	constexpr float pmin = SHD_PMIN;
	float v = max(vmin, mmts.y - mmts.x*mmts.x);
	float d = cmp - mmts.x;
	float p = v / (v + d*d);
	return (d < 0.f)? 1.f : saturate((p - pmin)/(1.f - pmin));
}
inline float shadow(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	constexpr sampler smp(filter::linear);
	constexpr int n = SHD_NPCF;
	float3 ndc = mmulw(lgt.proj, lgtbwd(lgt, pos));
	float2 loc = ndc2loc(ndc.xy);
	float cmp = ndc.z;
	float2 mmts = 0.f;
	for (int x = 0; x < n; ++x)
		for (int y = 0; y < n; ++y)
			mmts += shds.sample(smp, loc, lid, int2(x, y)-n/2).rg;
	return shadowcmp(cmp, mmts/(n*n));
}
inline float shadow_quad(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	return shadow(pos, lgt, shds, lid);
}
inline float shadow_cone(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	return shadow(pos, lgt, shds, lid);
}
inline float shadow_icos(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	return 1.f; // TODO: use orient?
}

inline float attenuation_rad(float3 pos, xlight lgt) {
	float sqd = length_squared(lgt.pos - pos);
	float sqr = lgt.rad * lgt.rad;
	return max(0.f, 1.f - sqd/sqr);
}
inline float attenuation_phi(float3 pos, xlight lgt) {
	float3 dir = normalize(lgt.pos - pos);
	float phi = angle(-lgt.dir, dir);
	return max(0.f, 1.f - phi/lgt.phi);
}
// xyz: normalized direction, w: attenuation
// TODO: use actual visible function pointers
inline float4 attenuate_quad(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	float3 dir = -lgt.dir;
	float  att = shadow_quad(pos, lgt, shds, lid);
	return float4(dir, att);
}
inline float4 attenuate_icos(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	float att = 1.f;
	att *= attenuation_rad(pos, lgt);
	if (att <= 0.f)
		return 0.f;
	att *= shadow_icos(pos, lgt, shds, lid);
	float3 dir = normalize(lgt.pos - pos);
	return float4(dir, att);
}
inline float4 attenuate_cone(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	float att = 1.f;
	att *= attenuation_rad(pos, lgt);
	att *= attenuation_phi(pos, lgt);
	if (att <= 0.f)
		return 0.f;
	att *= shadow_cone(pos, lgt, shds, lid);
	float3 dir = normalize(lgt.pos - pos);
	return float4(dir, att);
}
inline float4 dispatch_attenuate(float3 pos, xlight lgt, shadowmaps shds, uint lid) {
	if (is_qlight(lgt)) return attenuate_quad(pos, lgt, shds, lid);
	if (is_ilight(lgt)) return attenuate_icos(pos, lgt, shds, lid);
	return attenuate_cone(pos, lgt, shds, lid);
}

inline float3 bdrfd(float3 fd0, float ndl) {return max(0.f, ndl) * FD(fd0);}
inline float3 bdrfs(float3 fs0, float ndl, float ndv, float ndh, float ldh, float a) {
	float3 fs = FS(fs0, ldh);
	fs *= 0.25f / max(1e-8f, ndv);
	fs *= (ndh <= 0.f)? 0.f : NDF(a, ndh);
	fs *= (ndv <= 0.f)? 0.f : GSF(a, ndl, ndv, ndh, ldh);
	return fs;
}
float3 bdrf(xmaterial mat, float3 l, float3 v) {
	float3 n = normalize(mat.nml);
	float3 h = normalize(l + v);
	float ndl = max(0.f, dot(n, l));
	float ndv = max(0.f, dot(n, v));
	float ndh = max(0.f, dot(n, h));
	float ldh = max(0.f, dot(l, h));
	float3 fd = mix(mat.alb, 0.f, mat.mtl) * mat.ao;
	float3 fs = mix(BASE_F0, mat.alb, mat.mtl);
	fd = bdrfd(fd, ndl);
	fs = bdrfs(fs, ndl, ndv, ndh, ldh, mat.rgh);
	return saturate(fd + fs);
}

half3 com_lighting(xmaterial mat,
				   float3 pos,
				   float3 eye,
				   constant xlight *lgts,
				   shadowmaps shds,
				   uint lid) {
	xlight lgt = lgts[lid];
#if DEBUG_MASK
	return debug_mask(lgt);
#endif
	float4 att = dispatch_attenuate(pos, lgt, shds, lid);
	float3 dir = att.xyz;
	float3 rgb = att.a;
	rgb *= lgt.hue;
	rgb *= bdrf(mat, dir, eye);
	return (half3)saturate(rgb);
}
