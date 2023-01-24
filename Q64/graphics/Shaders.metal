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
	m4f ctm;
} svtx;
typedef struct {
	v3f cam;
	int nlt;
} sfrg;

typedef struct {
	v3f pos;
	v3f hue;
} lsrc;


static inline frg _vtx_base(vtx v,
			  constant mvtx &model,
			  constant svtx &scene) {

	v4f pos = model.ctm * v4f(v.pos, 1);
	v4f nml = model.ctm * v4f(v.nml, 0);

	return {
		.screen = scene.ctm * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
		.tex = v.tex,
		.hue = model.hue,
	};

}

static inline half4 _frg_base(frg f,
							constant mfrg &model,
							constant sfrg &scene,
							constant lsrc *lts
) {

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
	return half4(half3(spec + diff * f.hue.rgb), f.hue.a);

}


vertex frg vtx_main(vtx v					[[stage_in]],
					constant mvtx *models	[[buffer(1)]],
					constant svtx &scene	[[buffer(2)]],
					uint modelID			[[instance_id]]) {
	constant mvtx &model = models[modelID];
	return _vtx_base(v, model, scene);
}

fragment half4 frg_main(frg f [[stage_in]],
					  constant mfrg &model	[[buffer(1)]],
					  constant sfrg &scene	[[buffer(2)]],
					  constant lsrc *lts	[[buffer(3)]]) {
	return _frg_base(f, model, scene, lts);
}

fragment half4 frg_text(frg f [[stage_in]],
					  constant mfrg &model	[[buffer(1)]],
					  constant sfrg &scene	[[buffer(2)]],
					  constant lsrc *lts	[[buffer(3)]],
					  texture2d<f32, access::sample> map	[[texture(0)]],
					  sampler smp							[[sampler(0)]]) {
	f.hue *= map.sample(smp, f.tex);
	return _frg_base(f, model, scene, lts);
}
