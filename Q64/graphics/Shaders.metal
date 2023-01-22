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
	v3f hue;
	f32 diff;
	f32 spec;
	f32 shine;
} material;
typedef struct {
	v3f pos;
	v3f hue;
} lighting;


vertex frg vtx_main(const vtx v				[[stage_in]],
					constant m4f &model		[[buffer(1)]],
					constant m4f &scene		[[buffer(2)]]) {
	v4f pos = model * v4f(v.pos, 1);
	v4f nml = model * v4f(v.nml, 0);
	return {
		.spos = scene * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
	};
}

fragment v4f frg_main(const frg f				[[stage_in]],
					  constant material &mat 	[[buffer(1)]],
					  constant v3f &cam 		[[buffer(2)]],
					  device lighting *lts 		[[buffer(3)]],
					  constant int &nlt 		[[buffer(4)]]) {

	v3f diff = 0;
	v3f spec = 0;
	
	for (int i = 0; i < nlt; ++i) {
		lighting l = lts[i];
		
		v3f src = normalize(l.pos - f.pos);
		v3f dst = normalize(f.pos - cam);
		v3f ref = reflect(dst, f.nml);
		
		f32 ksrc = max(0.0, dot(src, f.nml));
		f32 kdst = max(0.0, dot(src, ref));
		
		v3f hue = l.hue / length_squared(l.pos - f.pos);
		diff += hue * ksrc;
		spec += hue * pow(kdst, mat.shine);
		
	}

	diff *= mat.diff;
	spec *= mat.spec;
	return v4f(spec + diff * mat.hue, 1);
	
}
