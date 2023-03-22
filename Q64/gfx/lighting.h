#ifndef com_lighting_h
#define com_lighting_h

#include <metal_stdlib>
using namespace metal;

#include "config.h"
#include "util.h"
#include "unifs.h"
#include "lighting_model.h"


static inline float shadowcmp(float cmp, float2 m) {
	constexpr float vmin = SHD_VMIN;
	constexpr float pmin = SHD_PMIN;
	float v = max(vmin, m.y - m.x*m.x);
	float d = cmp - m.x;
	float p = v / (v + d*d);
	return (d < 0.f)? 1.f : saturate((p - pmin)/(1.f - pmin));
}
static inline float shadow(shadowmaps shds, light lgt, uint lid, float3 pos) {
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
static inline float shadow_quad(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return shadow(shds, lgt, lid, pos);
}
static inline float shadow_cone(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return shadow(shds, lgt, lid, pos);
}
static inline float shadow_icos(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return 1.f; // TODO: use orient?
}

// xyz: normalized direction, w: attenuation
// TODO: use actual visible function pointers
typedef float4 (*attenuator)(float3 pos, light lgt, shadowmaps shds, uint lid);
static inline float4 attenuate_quad(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return float4(-lgt.dir, shadow_quad(pos, lgt, shds, lid));
}
static inline float4 attenuate_icos(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float3 dir = lgt.pos - pos;
	float rad = length(dir);
	float att = 1.f - rad/lgt.rad;
	if (att <= 0.f)
		return 0.f;
	dir /= rad;
	return float4(dir, att * shadow_icos(pos, lgt, shds, lid));
}
static inline float4 attenuate_cone(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float att = 1.f;
	float3 dir = lgt.pos - pos;
	float rad = length(dir);
	float phi = angle(-lgt.dir, dir /= rad);
	att *= max(0.f, 1.f - rad/lgt.rad);
	att *= max(0.f, 1.f - phi/lgt.phi);
	if (att <= 0.f)
		return 0.f;
	return float4(dir, att * shadow_cone(pos, lgt, shds, lid));
}
static inline float4 dispatch_attenuate(float3 pos, light lgt, shadowmaps shds, uint lid) {
	if (is_qlight(lgt)) return attenuate_quad(pos, lgt, shds, lid);
	if (is_ilight(lgt)) return attenuate_icos(pos, lgt, shds, lid);
	return attenuate_cone(pos, lgt, shds, lid);
}

static inline float3 bdrfd(float3 fd0, float ndl) {return max(0.f, ndl) * FD(fd0);}
static inline float3 bdrfs(float3 fs0, float ndl, float ndv, float ndh, float ldh, float a) {
	float3 fs = FS(fs0, ldh);
	fs *= 0.25f / max(1e-8, ndv);
	fs *= (ndh <= 0.f)? 0.f : NDF(a, ndh);
	fs *= (ndv <= 0.f)? 0.f : GSF(a, ndl, ndv);
	return fs;
}
static float3 bdrf(material mat, float3 l, float3 v) {
	float3 n = normalize(mat.nml);
	float3 h = normalize(l + v);
	float ndl = dot(n, l);
	float ndv = dot(n, v);
	float ndh = dot(n, h);
	float ldh = dot(l, h);
	float3 fd = mix(mat.alb, 0.f, mat.mtl) * mat.ao;
	float3 fs = mix(BASE_F0, mat.alb, mat.mtl);
	fd = bdrfd(fd, ndl);
	fs = bdrfs(fs, ndl, ndv, ndh, ldh, mat.rgh);
	return saturate(fd + fs);
}

half3 com_lighting(material mat,
				   float3 pos,
				   float3 eye,
				   constant light *lgts,
				   shadowmaps shds,
				   uint lid) {
	light lgt = lgts[lid];
#if DEBUG_MASK
	return debug_mask(lgt);
#endif
	float4 att = dispatch_attenuate(pos, lgt, shds, lid);
	if (att.a <= 0.f)
		return 0.h;
	float3 dir = att.xyz;
	float3 rgb = att.a;
	rgb *= lgt.hue;
	rgb *= bdrf(mat, dir, eye);
	return (half3)rgb;
}


#endif
