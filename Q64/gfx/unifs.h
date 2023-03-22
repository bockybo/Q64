#import <metal_stdlib>
using namespace metal;

#import "config.h"


using  pvtx = packed_float3;
struct mvtx {
	packed_float3 pos;
	packed_float3 nml;
	packed_float4 tgt;
	packed_float2 tex;
};
struct mfrg {
	float4 loc [[position]];
	float3 pos;
	float2 tex;
	float3 nml;
	float3 tgt;
	float3 btg;
	uint mat [[flat]];
};

struct lfrg {
	float4 loc [[position]];
	uint lid [[flat]];
};

// for dev clarity, tmp keep proj & view seperate
// but pack before bind down the road
struct camera {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	uint2 res;
};
struct scene {
	uint nlgt;
	camera cam;
};

struct model {
	float4x4 ctm;
	float4x4 inv;
	uint mat;
};

struct light {
	float4x4 proj;
	float3 hue;
	float3 pos;
	float3 dir;
	float rad;
	float phi;
};
using shadowmaps = texture2d_array<float>;

struct material {
	float3 alb;
	float3 nml;
	float  rgh;
	float  mtl;
	float   ao;
};
struct modelmaterial {
	texture2d<float> alb	[[texture(0)]];
	texture2d<float> nml	[[texture(1)]];
	texture2d<float> rgh	[[texture(2)]];
	texture2d<float> mtl	[[texture(3)]];
	texture2d<float>  ao	[[texture(4)]];
	material defaults		[[id(5)]];
};
using materialbuf = array<modelmaterial, NMATERIAL>;
