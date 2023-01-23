#include <metal_stdlib>
using namespace metal;


typedef float f32;
typedef float2 v2f;
typedef float3 v3f;
typedef float4 v4f;
typedef float4x4 m4f;


typedef struct {
	v3f pos;
	v3f hue;
} lsrc;

typedef struct {
	m4f ctm;
} mvtx;
typedef struct {
	v4f hue;
	f32 diff;
	f32 spec;
	f32 shine;
} mfrg;

typedef struct {
	m4f ctm;
} svtx;
typedef struct {
	v3f cam;
	int nlt;
} sfrg;

typedef struct {
	mvtx v;
	mfrg f;
} umodel;
typedef struct {
	svtx v;
	sfrg f;
} uscene;


typedef struct {
	v3f pos [[attribute(0)]];
	v3f nml	[[attribute(1)]];
	v2f tex	[[attribute(2)]];
} vtx;
typedef struct {
	v4f spos [[position]];
	v3f pos;
	v3f nml;
	v2f tex;
	mfrg model;
	sfrg scene;
} frg;


static inline frg _vtx_base(const vtx v,
							constant umodel &model,
							constant uscene &scene) {
	
	v4f pos = model.v.ctm * v4f(v.pos, 1);
	v4f nml = model.v.ctm * v4f(v.nml, 0);
	
	return {
		.spos = scene.v.ctm * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
		.tex = v.tex,
		.model = model.f,
		.scene = scene.f
	};
	
}

static inline v4f _frg_base(const frg f,
							const v4f base,
							constant lsrc *lts) {
	
	mfrg model = f.model;
	sfrg scene = f.scene;
	
	v3f diff = 0;
	v3f spec = 0;
	
	for (int i = 0; i < scene.nlt; ++i) {
		lsrc l = lts[i];
		
		v3f src = normalize(l.pos - f.pos);
		v3f dst = normalize(f.pos - scene.cam);
		
		f32 ksrc = max(0.0, dot(src, f.nml));
		f32 kdst = max(0.0, dot(src, reflect(dst, f.nml)));
		
		v3f hue = l.hue / length_squared(l.pos - f.pos);
		diff += hue * ksrc;
		spec += hue * pow(kdst, model.shine);
		
	}
	
	diff *= model.diff;
	spec *= model.spec;
	return v4f(spec + diff * base.rgb, base.a);
	
}


vertex frg vtx_main(const vtx v				[[stage_in]],
					constant umodel &model	[[buffer(1)]],
					constant uscene &scene	[[buffer(2)]]) {
	return _vtx_base(v, model, scene);
}

vertex frg vtx_inst(const vtx v				[[stage_in]],
					constant umodel *models	[[buffer(1)]],
					constant uscene &scene	[[buffer(2)]],
					uint modelID			[[instance_id]]) {
	constant umodel &model = models[modelID];
	return _vtx_base(v, model, scene);
}

fragment v4f frg_main(const frg f			[[stage_in]],
					  constant lsrc *lts	[[buffer(1)]]) {
	v4f base = f.model.hue;
	return _frg_base(f, base, lts);
}

fragment v4f frg_text(const frg f							[[stage_in]],
					  constant lsrc *lts					[[buffer(1)]],
					  texture2d<f32, access::sample> map	[[texture(0)]],
					  sampler smp							[[sampler(0)]]) {
	v4f base = f.model.hue * map.sample(smp, f.tex);
	return _frg_base(f, base, lts);
}
