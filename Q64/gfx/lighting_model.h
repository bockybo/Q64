#import <metal_stdlib>
using namespace metal;


inline float3 FD_lambert(float3 fd0) {
	return fd0 / M_PI_F;
}

inline float3 FS_schlick(float3 fs0, float ldh) {
	return fs0 + (1.f - fs0) * powr(1.f - abs(ldh), 5.f);
}

inline float NDF_blinnphong(float alpha, float ndh) {
	return pow(ndh, alpha) / M_PI_F;
}
inline float NDF_ggx(float alpha, float ndh) {
	float a2 = alpha * alpha;
	float csq = ndh * ndh;
	float tsq = (1 - csq) / max(1e-4, csq);
	return sqrt(alpha/(csq * (a2 + tsq))) / M_PI_F;
}
inline float NDF_trowreitz(float alpha, float ndh) {
	float a2 = alpha * alpha;
	float c = max(1e-3, 1.f + (a2 - 1.f) * ndh*ndh);
	return a2 / (M_PI_F*c*c);
}

inline float GSF_ggxwalter(float alpha, float ndl, float ndv) {
	float a2 = alpha * alpha;
	float ndl2 = ndl * ndl;
	float ndv2 = ndv * ndv;
	float lbot = ndl + sqrt(a2 + (1 - a2)/max(1e-4, ndl2));
	float vbot = ndv + sqrt(a2 + (1 - a2)/max(1e-4, ndv2));
	return 4.f * ndl*ndv / (lbot*vbot);
}
inline float GSF_ggxschlick(float alpha, float ndl, float ndv) {
	return 1.f;
	float ha = alpha * 0.5f;
	float lbot = ndl * (1.f - ha) + ha;
	float vbot = ndv * (1.f - ha) + ha;
	return ndl*ndv / (lbot*vbot);
}
