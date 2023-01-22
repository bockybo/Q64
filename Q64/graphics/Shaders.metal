#include <metal_stdlib>
using namespace metal;


typedef float f32;
typedef float3 v3f;
typedef float4 v4f;
typedef float4x4 m4f;


typedef struct {
	v3f pos [[attribute(0)]];
	v3f nml	[[attribute(1)]];
} vtx;
typedef struct {
	v4f spos [[position]];
	v3f pos;
	v3f nml;
} frg;

typedef struct {
	v3f pos;
	v3f hue;
} lsrc;

typedef struct {
	m4f ctm;
} svtx;
typedef struct {
	v3f cam;
	int nlt;
} sfrg;

typedef struct {
	m4f ctm;
} mvtx;
typedef struct {
	v3f hue;
	f32 diff;
	f32 spec;
	f32 shine;
} mfrg;


static inline frg _vtx_base(const vtx v,
							constant mvtx &model,
							constant svtx &scene) {
	
	v4f pos = model.ctm * v4f(v.pos, 1);
	v4f nml = model.ctm * v4f(v.nml, 0);
	
	return {
		.spos = scene.ctm * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
	};
	
}

static inline v4f _frg_base(const frg f,
							constant mfrg &model,
							constant sfrg &scene,
							constant lsrc *lts) {
	
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
	v3f base = model.hue;
	return v4f(spec + diff * base, 1);
	
}


vertex frg vtx_main(const vtx v				[[stage_in]],
					constant mvtx &model	[[buffer(1)]],
					constant svtx &scene	[[buffer(2)]]) {
	return _vtx_base(v, model, scene);
}

vertex frg vtx_inst(const vtx v				[[stage_in]],
					constant mvtx *models	[[buffer(1)]],
					constant svtx &scene	[[buffer(2)]],
					uint modelID			[[instance_id]]) {
	constant mvtx &model = models[modelID];
	return _vtx_base(v, model, scene);
}

fragment v4f frg_main(const frg f			[[stage_in]],
					  constant mfrg &model	[[buffer(1)]],
					  constant sfrg &scene	[[buffer(2)]],
					  constant lsrc *lts	[[buffer(3)]]) {
	return _frg_base(f, model, scene, lts);
}

//fragment v4f frg_text(const frg f							[[stage_in]],
//					  constant mfrg &model					[[buffer(1)]],
//					  constant sfrg &scene					[[buffer(2)]],
//					  constant lsrc *lts					[[buffer(3)]],
//					  texture2d<float, access::sample> map	[[texture(0)]],
//					  sampler sampler						[[sampler(0)]]) {
//	v4f hue = map.sample(sampler, f.tex);
//	return _frg_base(f, model, scene, lts);
//}
