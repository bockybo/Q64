#include <metal_stdlib>
using namespace metal;


typedef float f32;
typedef float2 v2f;
typedef float3 v3f;
typedef float4 v4f;
typedef float4x4 m4f;


typedef struct {
	v3f pos [[attribute(0)]];
	v3f nml [[attribute(1)]];
	v2f tex [[attribute(2)]];
} vtx;
typedef struct {
	v4f screen [[position]];
	v3f pos;
	v3f nml;
	v4f shd;
	v2f tex;
} frg;

typedef struct {
	f32 ambi;
	f32 diff;
	f32 spec;
	f32 shine;
} mfrg;

typedef struct {
	v3f hue;
	v3f dir;
} lfrg;


vertex frg vtx_light(vtx v									[[stage_in]],
					 constant m4f *models					[[buffer(1)]],
					 constant m4f &light					[[buffer(2)]],
					 constant m4f &scene					[[buffer(3)]],
					 uint modelID							[[instance_id]]) {
	
	constant m4f &model = models[modelID];
	
	v4f pos = model * v4f(v.pos, 1);
	v4f nml = model * v4f(v.nml, 0);
	
	v4f shd = light * pos;
	shd.xy /= shd.w;
	shd.xy = 0.5 * (1 + shd.xy);
	shd.y = 1 - shd.y;
	
	return {
		.screen = scene * pos,
		.pos = pos.xyz,
		.nml = nml.xyz,
		.shd = shd,
		.tex = v.tex,
	};
	
}

vertex v4f vtx_shade(const vtx v							[[stage_in]],
					 constant m4f *models					[[buffer(1)]],
					 constant m4f &light					[[buffer(2)]],
					 uint modelID							[[instance_id]]) {
	constant m4f &model = models[modelID];
	return light * model * v4f(v.pos, 1);
}

fragment v4f frg_main(frg f									[[stage_in]],
					  constant mfrg &model					[[buffer(1)]],
					  constant lfrg &lighting				[[buffer(2)]],
					  constant v3f &eye						[[buffer(3)]],
					  texture2d<f32, access::sample> texmap	[[texture(0)]],
					  depth2d  <f32, access::sample> shdmap	[[texture(1)]]) {
	
	constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
	
	v4f tex = texmap.sample(smp, f.tex);
	f32 dep = shdmap.sample(smp, f.shd.xy);
	
	if (f.shd.z >= f.shd.w * (dep + 1e-4))
		return v4f(0, 0, 0, tex.a);
		
	v3f dir = -lighting.dir;
	v3f nml = normalize(f.nml);
	f32 diff = saturate(dot(dir, nml));
	f32 spec = saturate(dot(eye, reflect(dir, -nml)));
	
	f32 lum = model.ambi;
	lum += model.diff * diff;
	lum += model.spec * powr(spec, model.shine);
	
	v4f rgb = v4f(lum * lighting.hue, 1);
	return tex * rgb;
	
}
