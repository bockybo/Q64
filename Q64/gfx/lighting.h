#import <metal_stdlib>
using namespace metal;

#import "shared.h"
#import "culling.h"


using shadowmaps = texture2d_array<float>;

half3 com_lighting(xmaterial mat,
				   float3 pos,
				   float3 eye,
				   constant xlight *lgts,
				   shadowmaps shds,
				   uint lid);

inline half3 debug_mask(xlight lgt);
inline half3 debug_cull(uint msk);
