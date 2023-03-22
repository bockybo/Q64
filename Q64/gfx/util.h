#import <metal_stdlib>
using namespace metal;

#import "unifs.h"
#import "types.h"


inline float4 mmul4(float4x4 mat, float4 vec) {return mat * vec;}
inline float3 mmul3(float4x4 mat, float4 vec) {return (mat * vec).xyz;}
inline float3 mmulw(float4x4 mat, float4 vec) {float4 r = mat * vec; return r.xyz / r.w;}
inline float4 mmul4(float4x4 mat, float3 vec, float w = 1.f) {return mmul4(mat, float4(vec, w));}
inline float3 mmul3(float4x4 mat, float3 vec, float w = 1.f) {return mmul3(mat, float4(vec, w));}
inline float3 mmulw(float4x4 mat, float3 vec, float w = 1.f) {return mmulw(mat, float4(vec, w));}

inline float2 loc2ndc(float2 loc) {return float2((2.0f * loc.x) - 1.0f, 1.0f - (2.0f * loc.y));}
inline float2 ndc2loc(float2 ndc) {return float2((1.0f + ndc.x) * 0.5f, 0.5f * (1.0f - ndc.y));}

inline float3 viewpos(float4x4 view) {return view[3].xyz;}
inline float3 viewdlt(float4x4 view) {return view[2].xyz;}
inline float3 viewdir(float4x4 view) {return normalize(viewdlt(view));}
inline float viewsqd(float4x4 view) {return length_squared(viewdlt(view));}
inline float viewlen(float4x4 view) {return length(viewdlt(view));}

inline float3x3 orient(float3 f, float3 up = float3(0.f, 1.f, 0.f)) {
	float3 s = normalize(cross(f, up));
	float3 u = normalize(cross(s, f));
	return {s, u, -f};
}
inline float angle(float3 a, float3 b) {
	return acos(dot(a, b));
}

inline float4 scrpos(camera cam, float3 pos) {
	return mmul4(cam.proj * cam.invview, pos);
}
inline float3 wldpos(camera cam, float3 ndc) {
	return mmulw(cam.view * cam.invproj, ndc);
}
inline float3 eyedir(camera cam, float3 pos) {
	return normalize(viewpos(cam.view) - pos);
}

inline float4 make_plane(float3 p0, float3 p1, float3 p2) {
	float3 d0 = p0 - p2;
	float3 d1 = p1 - p2;
	float3 n = normalize(cross(d0, d1));
	return float4(n, dot(n, p2));
}
inline bool inplane(float4 plane, float3 pos, float eps = 0.f) {
	return eps >= plane.w - dot(plane.xyz, pos);
}
inline bool inplane(float4 plane, float3 p, float3 d) {
	return inplane(plane, p) || inplane(plane, p + d);
}

inline bool is_qlight(light lgt) {return lgt.phi == -1.f;}
inline bool is_ilight(light lgt) {return lgt.phi ==  0.f;}
inline bool is_clight(light lgt) {return lgt.phi > 0.f;}
inline float3 lgtfwd(light lgt, float3 pos) {
	pos = orient(lgt.dir) * pos;
	pos *= lgt.rad;
	pos += lgt.pos;
	return pos;
}
inline float3 lgtbwd(light lgt, float3 pos) {
	pos -= lgt.pos;
	pos /= lgt.rad;
	pos = transpose(orient(lgt.dir)) * pos;
	return pos;
}

inline float3 smpdefault(sampler smp, float2 uv, texture2d<float> tex, float3 def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).rgb);
}
inline material materialsmp(const mfrg f, constant materialbuf &materials) {
	constexpr sampler smp(address::repeat);
	constant modelmaterial &mmat = materials[f.mat];
	material mat;
	mat.alb = smpdefault(smp, f.tex, mmat.alb, mmat.defaults.alb);
	mat.nml = smpdefault(smp, f.tex, mmat.nml, mmat.defaults.nml);
	mat.rgh = smpdefault(smp, f.tex, mmat.rgh, mmat.defaults.rgh).r;
	mat.mtl = smpdefault(smp, f.tex, mmat.mtl, mmat.defaults.mtl).r;
	mat. ao = smpdefault(smp, f.tex, mmat. ao, mmat.defaults. ao).r;
	float3x3 tbn = {f.tgt, f.btg, f.nml};
	mat.nml = normalize(tbn * normalize(mat.nml * 2.h - 1.h));
	return mat;
}

inline uint mskc(uint nlgt) {
	return !nlgt? 0u : -1u >> (32u - ((nlgt < 32u)? nlgt : 32u));
}
inline uint mskp(threadgroup tile &tile) {
	return atomic_load_explicit(&tile.msk, memory_order_relaxed);
}

inline half3 debug_mask(light lgt) {
	return (half3)normalize(lgt.hue) * 0.2h;
}
inline half3 debug_cull(uint msk) {
	constexpr half3 a = half3( 16,  16,  32);
	constexpr half3 b = half3(256, 128,   0);
	half x = (half)popcount(msk) / 32.h;
	return mix(a, b, x)/256.h;
}
