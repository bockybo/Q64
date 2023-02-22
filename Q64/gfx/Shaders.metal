#include <metal_stdlib>
using namespace metal;



typedef texture2d<float, access::sample> texmap2;
typedef   depth2d<float, access::sample> depmap2;


typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
} ldst;
typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
	half4 alb [[color(1), raster_order_group(1)]];
	half4 nml [[color(2), raster_order_group(1)]];
	float dep [[color(3), raster_order_group(1)]];
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
	uint iid [[flat]];
} frg;

typedef struct {
	float4x4 ctm;
	float3 hue;
	float shn;
} model;

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
static inline float3 phong(float3 alb,
						   float shn,
						   float3 pos,
						   float3 nml,
						   float3 eye,
						   float3 dir) {
	constexpr float ampdiff = 0.8;
	constexpr float ampspec = 0.5;
	float k = dot(nml, dir);
	if (k < 0)
		return 0;
	float3 rgb = ampdiff * max(0.0f, k) * alb;
	if (shn) {
		shn *= 255.0f;
		float3 ref = dir - 2*nml*k;
		float3 dir = normalize(pos - eye);
		float b = saturate(dot(dir, ref));
		if (shn > 0)
			rgb += ampspec * powr(b, shn);
		else
			rgb += ampspec * powr(b, -shn) * alb;
	}
	return rgb;
}
static inline float3 light(constant lfrg &lgt,
						   gbuf buf,
						   float3 pos,
						   float3 eye) {
	constexpr float ambi = 0.1;
	
	float3 alb = (float3)buf.alb.rgb; float shd = buf.alb.a;
	float3 nml = (float3)buf.nml.xyz; float shn = buf.nml.w;
	
	float lit;
	float3 rgb;
	float3 dir;
	if (!lgt.rad) {
		lit = 1 - shd;
		dir = lgt.dir;
		rgb = alb * ambi;
		if (!lit)
			return lgt.hue * rgb;
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
	rgb += lit * lgt.hue * phong(alb,
								 shn,
								 pos,
								 nml,
								 eye,
								 dir);
	return rgb;
}


vertex float4 vtx_shade(const device vtx *vtcs		[[buffer(0)]],
						constant model *mdls		[[buffer(1)]],
						constant float4x4 &lgtctm	[[buffer(2)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	constant model &mdl = mdls[iid];
	float3 v = vtcs[vid].pos;
	return lgtctm * mdl.ctm * float4(v, 1);
}

vertex frg vtx_gbuf(const device vtx *vtcs			[[buffer(0)]],
					constant model *mdls			[[buffer(1)]],
					constant float4x4 &lgtctm		[[buffer(2)]],
					constant float4x4 &camctm		[[buffer(3)]],
					uint vid						[[vertex_id]],
					uint iid						[[instance_id]]) {
	constant model &mdl = mdls[iid];
	vtx v = vtcs[vid];
	float4 pos = mdl.ctm * float4(v.pos, 1);
	float4 nml = mdl.ctm * float4(v.nml, 0);
	return {
		.camloc = camctm * pos,
		.lgtloc = lgtctm * pos,
		.texloc = v.tex,
		.nml = normalize(nml.xyz),
		.iid = iid,
	};
}
fragment gbuf frg_gbuf(const frg f					[[stage_in]],
					   constant model *mdls			[[buffer(1)]],
					   texmap2 albmap				[[texture(0)]],
					   depmap2 shdmap				[[texture(1)]]) {
	constant model &mdl = mdls[f.iid];
	float3 alb = color(f.texloc, albmap) * mdl.hue;
	float  shd = shade(f.lgtloc, shdmap);
	return {
		.dst = half4(0),
		.alb = half4((half3)alb, shd),
		.nml = half4((half3)f.nml, mdl.shn/255.0f),
		.dep = f.camloc.z,
	};
}


vertex lpix vtx_quad(const device packed_float3 *vtcs	[[buffer(0)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float3 pos = vtcs[vid];
	float4 loc = float4(pos, 1);
	return {.loc = loc, .iid = iid};
}
vertex lpix vtx_icos(const device packed_float3 *vtcs	[[buffer(0)]],
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
vertex float4 vtx_mask(const device packed_float3 *vtcs	[[buffer(0)]],
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

fragment ldst frg_light(const gbuf buf,
						const lpix pix					[[stage_in]],
						constant lfrg *lgts				[[buffer(2)]],
						constant float4x4 &inv			[[buffer(3)]],
						constant float3 &eye			[[buffer(4)]],
						constant uint2 &res				[[buffer(5)]]) {
	
	float2 uv = pix.loc.xy;
	uv *= 2 / (float2)res;
	uv = float2(uv.x - 1, 1 - uv.y);
	float4 pos = inv * float4(uv, buf.dep, 1);
	
	float3 rgb = light(lgts[pix.iid], buf, pos.xyz/pos.w, eye);
	return {buf.dst + half4((half3)rgb, 0)};
	
}
