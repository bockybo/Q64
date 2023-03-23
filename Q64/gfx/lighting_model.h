#import <metal_stdlib>
using namespace metal;


inline float3 FD_lambert(float3 fd0) {
	return fd0 / M_PI_F;
}

inline float3 FS_schlick(float3 fs0, float ldh) {
	return fs0 + (1.f - fs0) * powr(1.f - abs(ldh), 5.f);
}

inline float NDF_ggx(float alpha, float ndh) {
	float a2 = alpha * alpha;
	float csq = ndh * ndh;
	float bot = csq * (a2 - 1.f) + 1.f;
	return a2 / max(1e-8f, bot * bot);
}
inline float NDF_beckmann(float alpha, float ndh) {
	float a2 = alpha * alpha;
	float csq = ndh * ndh;
	float bot = a2 * csq * csq;
	return exp((csq - 1.f) / (a2 * csq)) / bot;
}

inline float GSF_smith(float alpha, float ndx) {
	float ha2 = alpha * alpha * 0.5f;
	return 1.f / (ndx * (1.f - ha2) + ha2);
}
inline float GSF_ggxwalter(float alpha, float ndx) {
	float a2 = alpha * alpha;
	float bot = ndx + sqrt(a2 + (1.f - a2)/(ndx*ndx));
	return 4.f * ndx / bot;
}
inline float GSF_ggxschlick(float alpha, float ndx) {
	float ha = alpha * 0.5f;
	float bot = ndx * (1.f - ha) + ha;
	return ndx / bot;
}
