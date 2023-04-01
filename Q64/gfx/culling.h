#import <metal_stdlib>
using namespace metal;


struct tile {
	atomic_uint msk;
	float mindepth;
	float maxdepth;
};

inline uint mskc(uint nlgt) {
	return -1u >> -min(0u, nlgt - MAX_NLIGHT);
}
inline uint mskp(threadgroup tile &tile) {
	return atomic_load_explicit(&tile.msk, memory_order_relaxed);
}
