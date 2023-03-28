#import <metal_stdlib>
using namespace metal;

#import "shared.h"


struct cpix {half4 color [[raster_order_group(0), color(0)]];};
struct dpix {float depth [[raster_order_group(0), color(1)]];};

inline float4 mmul4(float4x4 mat, float4 vec) {return mat * vec;}
inline float3 mmul3(float4x4 mat, float4 vec) {return (mat * vec).xyz;}
inline float3 mmulw(float4x4 mat, float4 vec) {float4 r = mat * vec; return r.xyz / r.w;}
inline float4 mmul4(float4x4 mat, float3 vec, float w = 1.f) {return mmul4(mat, float4(vec, w));}
inline float3 mmul3(float4x4 mat, float3 vec, float w = 1.f) {return mmul3(mat, float4(vec, w));}
inline float3 mmulw(float4x4 mat, float3 vec, float w = 1.f) {return mmulw(mat, float4(vec, w));}

inline float2 loc2ndc(float2 loc) {return float2((2.0f * loc.x) - 1.0f, 1.0f - (2.0f * loc.y));}
inline float2 ndc2loc(float2 ndc) {return float2((1.0f + ndc.x) * 0.5f, 0.5f * (1.0f - ndc.y));}
inline bool validloc(float2 loc) {return ( loc.x >=  0.f &&  loc.x <  1.f &&
										   loc.y >=  0.f &&  loc.y <  1.f);}
inline bool validndc(float2 ndc) {return (+ndc.x >= -1.f && +ndc.x < +1.f &&
										  -ndc.y >= -1.f && -ndc.y < +1.f);}

inline float3 viewpos(float4x4 view) {return view[3].xyz;}
inline float3 viewdlt(float4x4 view) {return view[2].xyz;}
inline float3 viewdir(float4x4 view) {return normalize(viewdlt(view));}
inline float viewsqd(float4x4 view) {return length_squared(viewdlt(view));}
inline float viewlen(float4x4 view) {return length(viewdlt(view));}

inline float angle(float3 a, float3 b) {
	return acos(dot(a, b));
}

inline bool istowards(float3 dir, float3 vec) {
	return all(sign(dir) != sign(-vec));
}
inline bool isaligned(float3 dir, float3 vec) {
	return dot(dir, vec) > 0.f;
}

typedef float3 (*director)(float3);
inline float3 direct0(float3 v) {return {-v.z, -v.y, -v.x};}
inline float3 direct1(float3 v) {return {+v.z, -v.y, +v.x};}
inline float3 direct2(float3 v) {return {+v.x, +v.z, -v.y};}
inline float3 direct3(float3 v) {return {+v.x, -v.z, +v.y};}
inline float3 direct4(float3 v) {return {+v.x, -v.y, -v.z};}
inline float3 direct5(float3 v) {return {-v.x, -v.y, +v.z};}
inline short faceof(float3 v) {
	// avoid branch returns
	// but TODO: must be a better way to get vector face
	short face = 0;
	face += 0 * (v.x > 0 && validndc(-float2(-v.z, -v.y) / -v.x));
	face += 1 * (v.x < 0 && validndc(-float2(+v.z, -v.y) / +v.x));
	face += 2 * (v.y > 0 && validndc(-float2(+v.x, +v.z) / -v.y));
	face += 3 * (v.y < 0 && validndc(-float2(+v.x, -v.z) / +v.y));
	face += 4 * (v.z > 0 && validndc(-float2(+v.x, -v.y) / -v.z));
	face += 5 * (v.z < 0 && validndc(-float2(-v.x, -v.y) / +v.z));
	return face;
}
inline float3 direct(float3 v, short face) {
	constexpr director directors[6] = {
		direct0, direct1, direct2,
		direct3, direct4, direct5};
	return directors[face % 6](v);
}
inline float3 direct(float3 v, float3 f) {
	constexpr float3 h = float3(0, 1, 0);
	float3 s = normalize(cross(f, h));
	float3 u = normalize(cross(s, f));
	return float3(dot(v,  s),
				  dot(v,  u),
				  dot(v, -f));
}

template <class T>
inline T unmix(T a, T b, T x) {return (x - a) / (b - a);}

inline float4 scrpos(xcamera cam, float3 pos) {
	return mmul4(cam.proj * cam.invview, pos);
}
inline float3 wldpos(xcamera cam, float3 ndc) {
	return mmulw(cam.view * cam.invproj, ndc);
}
inline float3 eyedir(xcamera cam, float3 pos) {
	return normalize(viewpos(cam.view) - pos);
}

inline float3 lgtpos(xlight lgt, float3 pos) {
	return direct(pos - lgt.pos, lgt.dir);
}
inline float3 lgtpos(xlight lgt, float3 pos, short face) {
	return direct(pos - lgt.pos, face);
}

inline bool is_qlight(xlight lgt) {return lgt.phi == -1.f;}
inline bool is_ilight(xlight lgt) {return lgt.phi ==  0.f;}
inline bool is_clight(xlight lgt) {return lgt.phi > 0.f;}

inline uint sid6(xscene scn, uint lid, uint amp) {
	uint i0 = scn.nlgt - scn.nilgt;
	return i0 + (lid - i0)*6 + amp;
}
