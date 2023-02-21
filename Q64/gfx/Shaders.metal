#include <metal_stdlib>
using namespace metal;



typedef texture2d<float, access::sample> texmap2;
typedef   depth2d<float, access::sample> depmap2;


typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
} gdst;
typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
	half4 alb [[color(1), raster_order_group(1)]];
	half4 nml [[color(2), raster_order_group(1)]];
	float2 dep [[color(3), raster_order_group(1)]];
} gbuf;
typedef struct {
	float4 loc [[position]];
	uint iid [[flat]];
} gpix;


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
	float dep;
	uint imf [[flat]];
} frg;

typedef struct {
	uint imf;
	float4x4 ctm;
} mvtx;
typedef struct {
	float3 ambi;
	float3 diff;
	float3 spec;
	float shine;
} mfrg;

typedef struct {
	float3 hue;
	float3 dir;
	float rad;
} lfrg;


static inline float3 color(float2 loc, texmap2 texmap) {
	constexpr sampler smp;
	if (is_null_texture(texmap))
		return 1;
	return texmap.sample(smp, loc).rgb;
}
static inline float shade(float4 loc, depmap2 shdmap) {
	constexpr sampler smp(compare_func::greater);
	constexpr int m = 8;
	float dep = loc.z / loc.w;
	float2 uv = loc.xy / loc.w;
	uv = 0.5 * float2(1 + uv.x, 1 - uv.y);
	int shd = 0;
	for (int x = 0; x < m; ++x)
		for (int y = 0; y < m; ++y)
			shd += shdmap.sample_compare(smp, uv, dep, int2(x, y) - m/2);
	return (float)shd / (m*m);
}
static inline lfrg attenuate(lfrg lgt, float3 pos) {
	float sqd = length_squared(lgt.dir -= pos);
	float sqr = lgt.rad * lgt.rad;
	lgt.hue *= 1 - sqd/sqr;
	lgt.dir = normalize(lgt.dir);
	return lgt;
}
static inline float3 light(lfrg lgt, mfrg mat, float3 pos, float3 nml, float3 eye) {
	float kdiff = saturate(dot(nml, lgt.dir));
	float kspec = saturate(dot(normalize(pos - eye), reflect(lgt.dir, nml)));
	float3 diff = mat.diff * kdiff;
	float3 spec = mat.spec * pow(kspec, mat.shine);
	return diff + spec;
}
static inline float3 loc_to_wld(float2 loc,
								float dep,
								constant float4x4 &invproj,
								constant float4x4 &invview,
								constant uint2 &res) {
	loc *= 2 / (float2)res;
	loc = float2(loc.x - 1, 1 - loc.y);
	float4 ndc = invproj * float4(loc, dep, 1); ndc.xyz /= ndc.w;
	float4 wld = invview * float4(ndc.xyz,  1); wld.xyz /= wld.w;
	return wld.xyz;
}


vertex float4 vtx_shade(constant vtx *vtcs			[[buffer(0)]],
						constant mvtx *mdls			[[buffer(1)]],
						constant float4x4 &lgtctm	[[buffer(2)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	float3 v = vtcs[vid].pos;
	mvtx mdl = mdls[iid];
	return lgtctm * mdl.ctm * float4(v, 1);
}

vertex frg vtx_gbuf(constant vtx *vtcs				[[buffer(0)]],
					constant mvtx *mdls				[[buffer(1)]],
					constant float4x4 &lgtctm		[[buffer(2)]],
					constant float4x4 &camctm		[[buffer(3)]],
					uint vid						[[vertex_id]],
					uint iid						[[instance_id]]) {
	vtx v = vtcs[vid];
	mvtx mdl = mdls[iid];
	float4 pos = mdl.ctm * float4(v.pos, 1);
	float4 nml = mdl.ctm * float4(v.nml, 0);
	return {
		.camloc = camctm * pos,
		.lgtloc = lgtctm * pos,
		.texloc = v.tex,
		.nml = normalize(nml.xyz),
		.imf = mdl.imf,
	};
}
fragment gbuf frg_gbuf(frg f						[[stage_in]],
					   texmap2 texmap				[[texture(0)]],
					   depmap2 shdmap				[[texture(1)]]) {
	float3 alb = color(f.texloc, texmap);
	float  shd = shade(f.lgtloc, shdmap);
	return {
		.dst = half4(0),
		.alb = half4((half3)alb, 0),
		.nml = half4((half3)f.nml, shd),
		.dep = float2(f.camloc.z, f.imf),
	};
}


vertex gpix vtx_quad(uint vid [[vertex_id]]) {
	constexpr float2 vtcs[] = {
		float2(-1,  1), float2( 1, -1), float2(-1, -1),
		float2(-1,  1), float2( 1,  1), float2( 1, -1),};
	float2 v = vtcs[vid];
	float4 loc = float4(v, 0, 1);
	return {.loc = loc, .iid = 0};
}
vertex gpix vtx_icos(constant packed_float3 *vtcs		[[buffer(0)]],
					 constant lfrg *lgts				[[buffer(2)]],
					 constant float4x4 &camctm			[[buffer(3)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	lfrg lgt = lgts[iid];
	float3 pos = lgt.dir + lgt.rad * v;
	float4 loc = camctm * float4(pos, 1);
	return {.loc = loc, .iid = iid};
}

fragment gdst frg_light(gbuf buf,
						gpix pix					[[stage_in]],
						constant mfrg *mats			[[buffer(1)]],
						constant lfrg *lgts			[[buffer(2)]],
						constant float4x4 &invproj	[[buffer(3)]],
						constant float4x4 &invview	[[buffer(4)]],
						constant uint2 &res			[[buffer(5)]]) {
	float3 alb = (float3)buf.alb.rgb;
	float3 nml = (float3)buf.nml.xyz;
	float shd = buf.nml.w;
	float dep = buf.dep.x;
	float imf = buf.dep.y;
	
	float3 pos = loc_to_wld(pix.loc.xy, dep, invproj, invview, res);
	
	mfrg mat = mats[(uint)imf];
	lfrg lgt = lgts[pix.iid];
	
	if (lgt.rad)
		lgt = attenuate(lgt, pos);
	
	float3 rgb = mat.ambi;
	float  lit = 1 - shd;
	if (lit)
		rgb += lit * light(lgt, mat, pos, nml, invview[3].xyz);
	rgb *= alb * lgt.hue;
	
	return {buf.dst + half4((half3)rgb, 0)};
	
}
