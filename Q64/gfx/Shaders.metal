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
} lpix;


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


static inline float3 color(float2 loc, texmap2 albmap) {
	constexpr sampler smp;
	if (is_null_texture(albmap))
		return 1;
	return albmap.sample(smp, loc).rgb;
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
static inline float3 light(constant lfrg &lgt,
						   constant mfrg &mat,
						   float shd,
						   float3 pos,
						   float3 nml,
						   float3 eye) {
	float lit;
	float3 rgb;
	float3 dir;
	if (!lgt.rad) {
		lit = 1 - shd;
		dir = lgt.dir;
		rgb = mat.ambi;
	} else {
		dir = lgt.dir - pos;
		float sqd = length_squared(dir);
		float sqr = lgt.rad * lgt.rad;
		if (sqd > sqr)
			return 0;
		float att = 1 - sqd/sqr;
		lit = att * att;
		dir = normalize(dir);
		rgb = 0;
	}
	if (lit > 0) {
		float kdiff = saturate(dot(nml, dir));
		float kspec = saturate(dot(normalize(pos - eye), reflect(dir, nml)));
		rgb += lit * mat.diff * kdiff;
		rgb += lit * mat.spec * pow(kspec, mat.shine);
	}
	return lgt.hue * rgb;
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
					   texmap2 albmap				[[texture(0)]],
					   depmap2 shdmap				[[texture(1)]]) {
	float3 alb = color(f.texloc, albmap);
	float  shd = shade(f.lgtloc, shdmap);
	return {
		.dst = half4(0),
		.alb = half4((half3)alb, 0),
		.nml = half4((half3)f.nml, shd),
		.dep = float2(f.camloc.z, f.imf),
	};
}


vertex lpix vtx_quad(constant packed_float3 *vtcs		[[buffer(0)]],
					 uint vid							[[vertex_id]]) {
	float3 pos = vtcs[vid];
	float4 loc = float4(pos, 1);
	return {.loc = loc, .iid = 0};
}
vertex lpix vtx_icos(constant packed_float3 *vtcs		[[buffer(0)]],
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
vertex float4 vtx_mask(constant packed_float3 *vtcs		[[buffer(0)]],
					   constant lfrg *lgts				[[buffer(2)]],
					   constant float4x4 &camctm		[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	lfrg lgt = lgts[iid];
	float3 pos = lgt.dir + lgt.rad * v;
	float4 loc = camctm * float4(pos, 1);
	return loc;
}

fragment gdst frg_light(gbuf buf,
						lpix pix						[[stage_in]],
						constant mfrg *mats				[[buffer(1)]],
						constant lfrg *lgts				[[buffer(2)]],
						constant float4x4 &invproj		[[buffer(3)]],
						constant float4x4 &invview		[[buffer(4)]],
						constant uint2 &res				[[buffer(5)]]) {
	float3 alb = (float3)buf.alb.rgb;
	float3 nml = (float3)buf.nml.xyz;
	float shd = buf.nml.w;
	float dep = buf.dep.x;
	float imf = buf.dep.y;
	
//	return {!lgts[pix.iid].rad ? 1 : buf.dst};
	
	float3 pos = loc_to_wld(pix.loc.xy, dep, invproj, invview, res);
	
	float3 rgb = alb * light(lgts[pix.iid],
							 mats[(uint)imf],
							 shd,
							 pos,
							 nml,
							 invview[3].xyz);
	
	return {buf.dst + half4((half3)rgb, 0)};
	
}
