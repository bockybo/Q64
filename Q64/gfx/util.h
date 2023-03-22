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

inline float4 scrpos(xcamera cam, float3 pos) {
	return mmul4(cam.proj * cam.invview, pos);
}
inline float3 wldpos(xcamera cam, float3 ndc) {
	return mmulw(cam.view * cam.invproj, ndc);
}
inline float3 eyedir(xcamera cam, float3 pos) {
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

inline bool is_qlight(xlight lgt) {return lgt.phi == -1.f;}
inline bool is_ilight(xlight lgt) {return lgt.phi ==  0.f;}
inline bool is_clight(xlight lgt) {return lgt.phi > 0.f;}
inline float3 lgtfwd(xlight lgt, float3 pos) {
	pos = orient(lgt.dir) * pos;
	pos *= lgt.rad;
	pos += lgt.pos;
	return pos;
}
inline float3 lgtbwd(xlight lgt, float3 pos) {
	pos -= lgt.pos;
	pos /= lgt.rad;
	pos = transpose(orient(lgt.dir)) * pos;
	return pos;
}
