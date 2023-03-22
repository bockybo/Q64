#ifndef types_h
#define types_h

#include <metal_stdlib>
using namespace metal;


struct cpix {half4 color [[raster_order_group(0), color(0)]];};

struct dpix {float depth [[raster_order_group(0), color(1)]];};

struct gbuf {
	float dep [[raster_order_group(1), color(1)]];
	half4 alb [[raster_order_group(1), color(2)]];
	half4 nml [[raster_order_group(1), color(3)]];
	half4 mat [[raster_order_group(1), color(4)]];
};

struct spix {
	float2 mmts [[raster_order_group(0), color(0)]];
};

struct tile {
	atomic_uint msk;
	float mindepth;
	float maxdepth;
};


#endif
