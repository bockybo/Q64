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
	float4 pos;
	float3 nml;
	float2 tex;
} frg;

typedef struct {
	float4x4 ctm;
} svtx;
typedef struct {
	float4x4 ctm;
} mvtx;
typedef struct {
	float4x4 lgtctm;
	float3 lgtsrc;
	float3 lgthue;
	float3 eyepos;
} sfrg;
typedef struct {
	float ambi;
	float diff;
	float spec;
	float shine;
} mfrg;

typedef struct {
	float4 pos [[color(0)]];
	float4 nml [[color(1)]];
	float4 alb [[color(2)]];
	float4 mat [[color(3)]];
} gbuf;

typedef struct {
	float4 loc [[position]];
} locfrg;


static inline float shade(float4 loc, depmap2 shdmap) {
	constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
	float z = loc.z;
	float w = loc.w;
	float2 xy = float2(w + loc.x, w - loc.y) / (2*w);
	constexpr int m = 4;
	int shd = 0;
	for (int x = 0; x < m; ++x)
		for (int y = 0; y < m; ++y)
			shd += z > w * shdmap.sample(smp, xy, int2(x, y) - m/2);
	return (float)shd / (m*m);
}


vertex frg vtx_main(constant vtx *vtcs			[[buffer(0)]],
					constant mvtx *mdls			[[buffer(1)]],
					constant svtx &scene		[[buffer(2)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &model = mdls[iid];
	float4 pos = model.ctm * float4(v.pos, 1);
	float4 nml = model.ctm * float4(v.nml, 0);
	return {
		.cam = scene.ctm * pos,
		.pos = pos,
		.nml = normalize(nml.xyz),
		.tex = v.tex,
	};
}

vertex float4 vtx_shadow(constant vtx *vtcs		[[buffer(0)]],
						 constant mvtx *mdls	[[buffer(1)]],
						 constant svtx &scene	[[buffer(2)]],
						 uint vid				[[vertex_id]],
						 uint iid				[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &model = mdls[iid];
	return scene.ctm * model.ctm * float4(v.pos, 1);
}

vertex locfrg vtx_quad(uint vid [[vertex_id]]) {
	constexpr float2 quad_vtcs[] = {
		float2(-1, -1), float2(+1, +1), float2(-1, +1),
		float2(-1, -1), float2(+1, +1), float2(+1, -1),
	};
	return {.loc = float4(quad_vtcs[vid], 0, 1)};
}


fragment gbuf frg_gbuf(frg f					[[stage_in]],
					   constant mfrg &model		[[buffer(1)]],
					   constant sfrg &scene		[[buffer(2)]],
					   texmap2 albmap			[[texture(0)]],
					   depmap2 shdmap			[[texture(1)]]) {
	constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear);
	float3 alb = albmap.sample(smp, f.tex).rgb;
	float shd = shade(scene.lgtctm * f.pos, shdmap);
	return {
		.pos = float4(f.pos.xyz, 0),
		.nml = float4(f.nml, 0),
		.alb = float4(alb, shd),
		.mat = float4(model.ambi, model.diff, model.spec, model.shine),
	};
}

fragment float4 frg_gdir(locfrg f				[[stage_in]],
						 constant sfrg &scene	[[buffer(2)]],
						 texmap2 posmap			[[texture(0)]],
						 texmap2 nmlmap			[[texture(1)]],
						 texmap2 albmap			[[texture(2)]],
						 texmap2 matmap			[[texture(3)]]) {
	uint2 loc = uint2(f.loc.xy);
	
	float3 pos = posmap.read(loc).xyz;
	float3 nml = nmlmap.read(loc).xyz;
	float4 mat = matmap.read(loc);
	float4 alb_shd = albmap.read(loc);
	float3 alb = alb_shd.rgb;
	float shd  = alb_shd.a;
	
	float3 rgb = 0;
	if (shd < 1) {
		float diff = dot(scene.lgtsrc, nml);
		float spec = dot(normalize(pos - scene.eyepos), reflect(scene.lgtsrc, nml));
		rgb += mat.y * saturate(diff);
		rgb += mat.z * saturate(powr(spec, mat.w));
		rgb *= 1 - shd;
	}
	rgb = (mat.x + rgb) * scene.lgthue * alb;
	
	return float4(rgb, 1);
}
