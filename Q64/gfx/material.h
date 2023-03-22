#import <metal_stdlib>
using namespace metal;

#import "shared.h"
#import "geometry.h"


struct material {
	texture2d<float> alb	[[texture(0)]];
	texture2d<float> nml	[[texture(1)]];
	texture2d<float> rgh	[[texture(2)]];
	texture2d<float> mtl	[[texture(3)]];
	texture2d<float>  ao	[[texture(4)]];
	xmaterial defaults		[[id(5)]];
};
using materialbuf = array<material, MAX_NMATERIAL>;

inline float3 smpdefault(sampler smp, float2 uv, texture2d<float> tex, float3 def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).rgb);
}
inline xmaterial materialsmp(geo g, constant materialbuf &materials) {
	constexpr sampler smp(address::repeat);
	constant material &mmat = materials[g.mat];
	xmaterial xmat;
	xmat.alb = smpdefault(smp, g.tex, mmat.alb, mmat.defaults.alb);
	xmat.nml = smpdefault(smp, g.tex, mmat.nml, mmat.defaults.nml);
	xmat.rgh = smpdefault(smp, g.tex, mmat.rgh, mmat.defaults.rgh).r;
	xmat.mtl = smpdefault(smp, g.tex, mmat.mtl, mmat.defaults.mtl).r;
	xmat. ao = smpdefault(smp, g.tex, mmat. ao, mmat.defaults. ao).r;
	float3x3 tbn = {g.tgt, g.btg, g.nml};
	xmat.nml = normalize(tbn * normalize(xmat.nml * 2.h - 1.h));
	return xmat;
}
