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

template <class T>
inline T unmix(T a, T b, T x) {return (x - a) / (b - a);}

inline float angle(float3 a, float3 b) {return acos(dot(a, b));}
inline float angle90(float3 a, float3 b) {
	float d = dot(a, b);
	return (d >= 0.f)? acos(d) : FLT_MAX;
}

inline float3 direct(float3 v, float3 f) {
	constexpr float3 h = float3(0, 1, 0);
	float3 s = normalize(cross(f, h));
	float3 u = normalize(cross(s, f));
	return float3(dot(v,  s),
				  dot(v,  u),
				  dot(v, -f));
}

typedef float3 (*_facefn)(float3);
inline float3 reface0(float3 v) {return {-v.z, -v.y, -v.x};}
inline float3 reface1(float3 v) {return {+v.z, -v.y, +v.x};}
inline float3 reface2(float3 v) {return {+v.x, +v.z, -v.y};}
inline float3 reface3(float3 v) {return {+v.x, -v.z, +v.y};}
inline float3 reface4(float3 v) {return {+v.x, -v.y, -v.z};}
inline float3 reface5(float3 v) {return {-v.x, -v.y, +v.z};}
inline float3 reface(float3 v, short i) {
	constexpr _facefn faces[6] = {
		reface0, reface1, reface2,
		reface3, reface4, reface5};
	return faces[i](v);
}

inline bool isfacing(float3 v, short i) {
	v = reface(v, i);
	return v.z > 0 && validndc(v.xy / v.z);
}
inline short faceof(float3 v) {
	short face = -1;
	for (int i = 0; i < 6; ++i)
		face = isfacing(v, i)? i : face;
	return face;
}

inline float4 scrpos(xcamera cam, float3 wld) {
	return mmul4(cam.proj * cam.invview, wld);
}
inline float3 eyepos(xcamera cam, float2 loc, float dep) {
	float2 ndc = loc2ndc(loc / (float2)cam.res);
	return mmulw(cam.invproj, float3(ndc, dep));
}
inline float3 wldpos(xcamera cam, float2 loc, float dep) {
	return mmul3(cam.view, eyepos(cam, loc, dep));
}

inline float3 eyedir(xcamera cam, float3 wld) {
	return normalize(viewpos(cam.view) - wld);
}

inline uint sid6(xscene scn, uint lid, uint amp) {
	uint i0 = scn.nlgt - scn.nilgt;
	return min((uint)MAX_NSHADE, i0 + (lid - i0)*6 + amp);
}

inline short light_type(xlight lgt) {return (bool)lgt.rad + (bool)lgt.phi;}
inline bool is_qlight(xlight lgt) {return light_type(lgt) == 0;}
inline bool is_ilight(xlight lgt) {return light_type(lgt) == 1;}
inline bool is_clight(xlight lgt) {return light_type(lgt) == 2;}
