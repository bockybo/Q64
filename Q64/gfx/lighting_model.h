#import <metal_stdlib>
using namespace metal;


static constexpr constant float DPI = 0.3183098862f; // 1/pi

inline float3 FD_lambert(float3 fd0) {
	return fd0 * DPI;
}

inline float3 FS_schlick(float3 fs0, float ldh) {
	return fs0 + (1.f - fs0) * powr(1.f - abs(ldh), 5.f);
}

inline float NDF_blinnphong(float alpha, float ndh) {
	return DPI * pow(ndh, alpha);
}
inline float NDF_ggx(float alpha, float ndh) {
	float a2 = alpha * alpha;
	float c2 = ndh * ndh;
	float bot = c2 * (a2 - 1.f) + 1.f;
	return DPI * a2 / max(1e-3, (bot * bot));
}
inline float NDF_beckmann(float alpha, float ndh) {
	float ndh2 = ndh * ndh;
	float ndh2a2 = ndh2 * alpha * alpha;
	return DPI * max(1e-6, exp((ndh2 - 1)/(ndh2a2)) / (ndh2a2*ndh2));
}
inline float NDF_gaussian(float alpha, float ndh) {
	float t = acos(ndh);
	return exp(-t * t / (alpha * alpha));
}

inline float GSF_ggxwalter(float alpha, float ndl, float ndv, float ndh, float ldh) {
	float a2 = alpha * alpha;
	float lbot = ndl + sqrt(a2 + (1.f - a2)/max(1e-4f, ndl * ndl));
	float vbot = ndv + sqrt(a2 + (1.f - a2)/max(1e-4f, ndv * ndv));
	return 4.f * ndl*ndv / (lbot*vbot);
}
inline float GSF_ggxschlick(float alpha, float ndl, float ndv, float ndh, float ldh) {
	return 1.f;
	float ha = alpha * 0.5f;
	float lbot = ndl * (1.f - ha) + ha;
	float vbot = ndv * (1.f - ha) + ha;
	return ndl*ndv / (lbot*vbot);
}
