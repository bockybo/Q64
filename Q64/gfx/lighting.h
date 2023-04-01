#import <metal_stdlib>
using namespace metal;

#import "shared.h"
#import "culling.h"


struct shadowmap {
	static constexpr sampler smp = sampler(filter::linear);
	texture2d_array<float> map;
	uint i;
	float2 sample(float2 loc, int2 off = 0);
};

float3 comx_lighting(float3 rgb,
					 float3 wld,
					 xmaterial mat,
					 constant xscene &scn,
					 constant xlight *lgts,
					 shadowmap shd);
