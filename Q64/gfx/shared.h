#import <simd/simd.h>

#import "config.h"


#ifndef __METAL_VERSION__
typedef struct __attribute__ ((packed)) packed_float3 {
	float x;
	float y;
	float z;
} packed_float3;
#endif

typedef simd_uint2 uint2;
typedef simd_uint3 uint3;
typedef simd_uint4 uint4;
typedef simd_int2 int2;
typedef simd_int3 int3;
typedef simd_int4 int4;

typedef simd_float2 float2;
typedef simd_float3 float3;
typedef simd_float4 float4;

typedef simd_float3x3 float3x3;
typedef simd_float4x4 float4x4;


typedef struct {
	float4x4 ctm;
	float4x4 inv;
	uint mat;
} xmodel;

typedef struct {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	float z0;
	float z1;
	uint2 res;
} xcamera;
typedef struct {
	xcamera cam;
	uint nlgt;
	uint nclgt;
	uint nilgt;
} xscene;

typedef struct {
	float4x4 proj;
	float3 hue;
	float3 pos;
	float3 dir;
	float rad;
	float phi;
} xlight;

typedef struct {
	float3 alb;
	float3 nml;
	float  rgh;
	float  mtl;
} xmaterial;
