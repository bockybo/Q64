#import <metal_stdlib>
using namespace metal;


struct geo {
	float4 scr [[position]];
	float3 pos;
	float2 tex;
	float3 nml;
	float3 tgt;
	float3 btg;
	uint mat [[flat]];
};
