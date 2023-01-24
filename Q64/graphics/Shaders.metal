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
	v3f eye;
	v2f tex;
	v4f hue;
} frg;

typedef struct {
	m4f ctm;
	v4f hue;
} mvtx;
typedef struct {
	f32 diff;
	f32 spec;
	f32 shine;
} mfrg;

typedef struct {
	m4f proj;
	m4f view;
} svtx;

#define MAXNLT 64
typedef struct {
	v3f pos;
	v3f hue;
	f32 amp;
} lsrc;


vertex frg vtx_main(vtx v									[[stage_in]],
					constant mvtx *models					[[buffer(1)]],
					constant svtx &scene					[[buffer(2)]],
					uint modelID							[[instance_id]]) {
	
	constant mvtx &model = models[modelID];
	
	v4f pos = model.ctm * v4f(v.pos, 1);
	v4f nml = model.ctm * v4f(v.nml, 0);
	
	return {
		.screen = scene.proj * scene.view * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
		.eye = normalize(pos.xyz - scene.view[3].xyz),
		.tex = v.tex,
		.hue = model.hue,
	};
	
}

fragment half4 frg_main(frg f								[[stage_in]],
						constant mfrg &model				[[buffer(1)]],
						constant lsrc *lts					[[buffer(2)]],
						texture2d<f32, access::sample> map	[[texture(0)]],
						sampler smp							[[sampler(0)]]) {
	
	v3f diff = 0;
	v3f spec = 0;
	
	for (int i = 0; i < MAXNLT; ++i) {
		lsrc l = lts[i];
		if (!l.amp)
			continue;
		
		v3f dist = l.pos - f.pos;
		v3f dir = normalize(dist);
		f32 kdiff = saturate(dot(f.nml, dir));
		f32 kspec = saturate(dot(f.eye, reflect(dir, f.nml)));
		
		f32 amp = l.amp / length_squared(dist);
		v3f hue = l.hue * amp;
		diff += hue * kdiff;
		spec += hue * powr(kspec, model.shine);
		
	}
	
	v4f base = f.hue * map.sample(smp, f.tex);
	diff *= model.diff;
	spec *= model.spec;
	half3 rgb = half3(spec + diff * base.rgb);
	return half4(rgb, base.a);
	
}
