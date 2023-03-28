#import <metal_stdlib>
using namespace metal;


inline float3 FD_lambert(float3 f0, float ldh, float ndl, float ndv, float a) {
	return f0 / M_PI_F;
}
inline float3 FD_disney(float3 f0, float ldh, float ndl, float ndv, float a) {
	float f90 = 0.5f + 2.f * ldh*ldh * a*a;
	f0 *= 1.f + (f90 - 1.f) * powr(1.f - ndl, 5.f);
	f0 *= 1.f + (f90 - 1.f) * powr(1.f - ndv, 5.f);
	return f0 / M_PI_F;
}

inline float3 FS_schlick(float3 f0, float ldh) {
	return f0 + (1.f - f0) * powr(1.f - ldh, 5.f);
}

inline float NDF_ggxtrowreitz(float a, float ndh) {
	float a2 = a * a;
	float csq = ndh * ndh;
	float bot = csq * (a2 - 1.f) + 1.f;
	return a2 / (M_PI_F * bot * bot);
}
inline float NDF_beckmann(float a, float ndh) {
	float a2 = a * a;
	float csq = ndh * ndh;
	float top = exp((csq - 1.f) / (a2 * csq));
	float bot = a2 * csq * csq;
	return top / (M_PI_F * bot);
}

inline float GSF_ggxschlick(float a, float ndx) {
	float ha2 = a * a * 0.5f;
	float bot = ndx * (1.f - ha2) + ha2;
	return ndx / bot;
}
inline float GSF_ggxwalter(float a, float ndx) {
	float a2 = a * a;
	float bot = ndx + sqrt(a2 + (1.f - a2) * ndx*ndx);
	return 2.f * ndx / bot;
}
inline float GSF_smith(float a, float ndx) {
	float a2 = a * a;
	float s1 = ndx * sqrt((a2 + 1) / (1.f - ndx*ndx));
	float top = (2.181f*s1 + 3.535f)*s1;
	float bot = (2.577f*s1 + 2.276f)*s1 + 1.f;
	return top / bot;
}
