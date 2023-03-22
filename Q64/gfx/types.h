#import <metal_stdlib>
using namespace metal;


struct cpix {
	half4 color [[raster_order_group(0), color(0)]];
};

struct dpix {
	float depth [[raster_order_group(0), color(1)]];
};

struct tile {
	atomic_uint msk;
	float mindepth;
	float maxdepth;
};
