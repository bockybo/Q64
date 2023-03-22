#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "unifs.h"
#import "lighting_model.h"


half3 com_lighting(material mat,
				   float3 pos,
				   float3 eye,
				   constant light *lgts,
				   shadowmaps shds,
				   uint lid);
