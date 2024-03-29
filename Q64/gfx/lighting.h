#import <metal_stdlib>
using namespace metal;

#import "shared.h"
#import "culling.h"


typedef texture2d_array<float> shadowmaps;

float3 comx_lighting(float3 rgb,
					 float3 wld,
					 xmaterial mat,
					 constant xscene &scn,
					 constant xlight *lgts,
					 shadowmaps shds,
					 uint lid);
