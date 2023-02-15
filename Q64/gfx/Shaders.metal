#include <metal_stdlib>
using namespace metal;


typedef texture2d<float, access::sample> texmap2;
typedef depth2d  <float, access::sample> depmap2;


typedef struct {
	packed_float3 pos;
	packed_float3 nml;
	packed_float2 tex;
} vtx;
typedef struct {
	float4 cam [[position]];
	float4 lgt;
	float3 pos;
	float3 nml;
	float2 tex;
} frg;

typedef struct {
	float4x4 lgt;
	float4x4 cam;
} svtx;
typedef struct {
	float4x4 ctm;
} mvtx;

typedef struct {
	float3 eyepos;
	float3 lgtpos;
	float3 lgthue;
} sfrg;
typedef struct {
	float3 ambi;
	float3 diff;
	float3 spec;
	float shine;
} mfrg;


vertex frg vtx_light(constant vtx *vtcs			[[buffer(0)]],
					 constant mvtx *mdls		[[buffer(1)]],
					 constant svtx &scene		[[buffer(2)]],
					 uint vid					[[vertex_id]],
					 uint iid					[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &model = mdls[iid];
	float4 pos = model.ctm * float4(v.pos, 1);
	float4 nml = model.ctm * float4(v.nml, 0);
	return {
		.cam = scene.cam * pos,
		.lgt = scene.lgt * pos,
		.pos = pos.xyz,
		.nml = normalize(nml.xyz),
		.tex = v.tex
	};
}
vertex float4 vtx_shade(constant vtx *vtcs		[[buffer(0)]],
						constant mvtx *mdls		[[buffer(1)]],
						constant svtx &scene	[[buffer(2)]],
						uint vid				[[vertex_id]],
						uint iid				[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &model = mdls[iid];
	return scene.lgt * model.ctm * float4(v.pos, 1);
}

static inline float shade(float4 loc, depmap2 shdmap) {
	constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
	float z = loc.z;
	float w = loc.w;
	float2 xy = float2(w + loc.x, w - loc.y) / (2*w);
	constexpr int m = 8;
	int shd = 0;
	for (int x = 0; x < m; ++x)
		for (int y = 0; y < m; ++y)
			shd += z > w * shdmap.sample(smp, xy, int2(x, y) - m/2);
	return (float)shd / (m*m);
}
static inline float2 light(float3 pos, float3 nml, float3 src, float3 dst) {
//	float3 dirdiff = normalize(src - pos);
	float3 dirdiff = normalize(-src);
	float3 dirspec = normalize(pos - dst);
	float diff = saturate(dot(dirdiff, nml));
	float spec = saturate(dot(dirspec, reflect(dirdiff, nml)));
	return float2(diff, spec);
}
fragment float4 frg_main(frg f					[[stage_in]],
						 constant mfrg &model	[[buffer(1)]],
						 constant sfrg &scene	[[buffer(2)]],
						 texmap2 albmap			[[texture(0)]],
						 depmap2 shdmap			[[texture(1)]]) {
	constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);

	float2 lit = light(f.pos, f.nml, scene.lgtpos, scene.eyepos);
	float diff = lit.x;
	float spec = lit.y;
	float shd = shade(f.lgt, shdmap);

	float3 rgb = 0;
	rgb += model.diff * diff;
	rgb += model.spec * powr(spec, model.shine);
	rgb *= 1 - shd;
	rgb += model.ambi;
	rgb *= scene.lgthue * albmap.sample(smp, f.tex).rgb;
	return float4(rgb, 1);
	
}
