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
	float4 camloc [[position]];
	float4 lgtloc;
	float2 texloc;
	float3 nml;
	float3 eye;
	float id;
} frg;

typedef struct {
	float4 alb [[color(0)]];
	float4 nml [[color(1)]];
	float4 eye [[color(2)]];
} gbuf;

typedef struct {
	float4 loc [[position]];
} locfrg;

typedef struct {
	float4x4 cam;
	float4x4 lgt;
	float3 eye;
} svtx;
typedef struct {
	uint id;
	float4x4 ctm;
} mvtx;
typedef struct {
	float3 lgtdir;
	float3 lgthue;
} sfrg;
typedef struct {
	float3 ambi;
	float3 diff;
	float3 spec;
	float shine;
} mfrg;

#define MAXID 128


static inline float3 color(float2 loc, texmap2 texmap) {
	constexpr sampler smp;
	return is_null_texture(texmap)? 1 : texmap.sample(smp, loc).rgb;
}
static inline float shade(float4 loc, depmap2 shdmap) {
	constexpr sampler smp(compare_func::greater);
	constexpr int m = 8;
	loc.xyz /= loc.w;
	loc.xy = 0.5 * float2(1 + loc.x, 1 - loc.y);
	int shd = 0;
	for (int x = 0; x < m; ++x)
		for (int y = 0; y < m; ++y)
			shd += shdmap.sample_compare(smp, loc.xy, loc.z, int2(x, y) - m/2);
	return (float)shd / (m*m);
}

static inline float4 phong(constant mfrg &mat,
						   float3 dir,
						   float3 hue,
						   float3 alb,
						   float3 nml,
						   float3 eye,
						   float shd) {
	float3 rgb = 0;
	if (shd < 1) {
		float diff = dot(dir, nml);
		float spec = dot(eye, dir - 2*nml*diff);
		rgb += mat.diff * saturate(diff);
		rgb += mat.spec * saturate(powr(spec, mat.shine));
		rgb *= 1 - shd;
	}
	rgb = (mat.ambi + rgb) * alb * hue;
	return float4(rgb, 1);
}


vertex float4 vtx_shdw(constant vtx *vtcs		[[buffer(0)]],
					   constant mvtx *mdls		[[buffer(1)]],
					   constant float4x4 &lgt	[[buffer(2)]],
					   uint vid					[[vertex_id]],
					   uint iid					[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &mdl = mdls[iid];
	return lgt * mdl.ctm * float4(v.pos, 1);
}

vertex frg vtx_main(constant vtx *vtcs			[[buffer(0)]],
					constant mvtx *mdls			[[buffer(1)]],
					constant svtx &scene		[[buffer(2)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	constant vtx &v = vtcs[vid];
	constant mvtx &mdl = mdls[iid];
	float4 pos = mdl.ctm * float4(v.pos, 1);
	float4 nml = mdl.ctm * float4(v.nml, 0);
	return {
		.camloc = scene.cam * pos,
		.lgtloc = scene.lgt * pos,
		.texloc = v.tex,
		.nml = normalize(nml.xyz),
		.eye = normalize(pos.xyz - scene.eye),
		.id = (float)mdl.id / MAXID
	};
}
fragment gbuf frg_main(frg f					[[stage_in]],
					   texmap2 texmap			[[texture(0)]],
					   depmap2 shdmap			[[texture(1)]]) {
	float3 alb = color(f.texloc, texmap);
	float  shd = shade(f.lgtloc, shdmap);
	return {
		.alb = float4(alb, f.id),
		.nml = float4(f.nml, shd),
		.eye = float4(f.eye, 0),
	};
}

vertex locfrg vtx_quad(uint vid [[vertex_id]]) {
	constexpr float2 quad_vtcs[] = {
		float2(-1, -1), float2(+1, +1), float2(-1, +1),
		float2(-1, -1), float2(+1, +1), float2(+1, -1),
	};
	return {.loc = float4(quad_vtcs[vid], 0, 1)};
}
fragment float4 frg_quad(locfrg f				[[stage_in]],
						 constant mfrg *mfrgs	[[buffer(1)]],
						 constant sfrg &scene	[[buffer(2)]],
						 texmap2 albmap			[[texture(0)]],
						 texmap2 nmlmap			[[texture(1)]],
						 texmap2 eyemap			[[texture(2)]]) {
	
	uint2 loc = uint2(f.loc.xy);
	float4 rd_alb = albmap.read(loc);
	float4 rd_nml = nmlmap.read(loc);
	float4 rd_eye = eyemap.read(loc);
	float3 alb = rd_alb.rgb; float  id = rd_alb.a;
	float3 nml = rd_nml.xyz; float shd = rd_nml.w;
	float3 eye = rd_eye.xyz; // TODO: USE W :)
	constant mfrg &mat = mfrgs[(uint)(id * MAXID)];
	float3 dir = -scene.lgtdir;
	float3 hue =  scene.lgthue;
	return phong(mat, dir, hue, alb, nml, eye, shd);
	
}
