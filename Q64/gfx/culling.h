#import <metal_stdlib>
using namespace metal;


struct tile {
	atomic_uint msk;
	float mindepth;
	float maxdepth;
};

inline uint mskc(uint nlgt) {
	return !nlgt? 0u : -1u >> (32u - ((nlgt < 32u)? nlgt : 32u));
}
inline uint mskp(threadgroup tile &tile) {
	return atomic_load_explicit(&tile.msk, memory_order_relaxed);
}
