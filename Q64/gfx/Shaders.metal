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
	uint iid [[flat]];
} frg;

typedef struct {
	float4x4 ctm;
	float3 hue;
	float rgh;
	float mtl;
} model;

typedef struct {
	float3 hue;
	float3 pos;
	float rad;
} light;


static inline float3 color(float2 loc, texmap2 albmap) {
	constexpr sampler smp;
	if (is_null_texture(albmap))
		return 1;
	return albmap.sample(smp, loc).rgb;
}
static inline float shade(float4 loc, depmap2 shdmap) {
	constexpr sampler smp(compare_func::greater);
	constexpr int m = 4;
	float dep = loc.z / loc.w;
	float2 uv = loc.xy / loc.w;
	uv = 0.5 * float2(1 + uv.x, 1 - uv.y);
	int shd = 0;
	for (int x = 0; x < m; ++x)
		for (int y = 0; y < m; ++y)
			shd += shdmap.sample_compare(smp, uv, dep, int2(x, y) - m/2);
	return (float)shd / (m*m);
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
					   texmap2 albmap				[[texture(1)]],
					   depmap2 shdmap				[[texture(2)]]) {
	constant model &mdl = mdls[f.iid];
	float3 nml = f.nml;
	float3 alb = color(f.texloc, albmap) * mdl.hue;
	float shd = shade(f.lgtloc, shdmap);
	float dep = f.camloc.z;
	return {
		.dst = 0,
		.alb = half4((half3)alb, mdl.rgh),
		.nml = half4((half3)nml, mdl.mtl),
		.dep = float2(dep, shd),
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
					 constant light *lgts				[[buffer(2)]],
					 constant float4x4 &cam				[[buffer(3)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	light lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * v;
	float4 loc = cam * float4(pos, 1);
	return {.loc = loc, .iid = iid};
}
vertex float4 vtx_mask(const device packed_float3 *vtcs	[[buffer(0)]],
					   constant light *lgts				[[buffer(2)]],
					   constant float4x4 &cam			[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	light lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * v;
	float4 loc = cam * float4(pos, 1);
	return loc;
}

#define AMBI 0.08f
#define DIFF 0.92f
#define DIAL 0.04f
static inline float G1(float asq, float ndx) {
	float cossq = ndx * ndx;
	float tansq = (1.0f - cossq) / max(cossq, 1e-4);
	return 2.0f / (1.0f + sqrt(1.0f + asq * tansq));
}
static inline float3 BDRF(float rgh,
						  float mtl,
						  float3 alb,
						  float3 nml, float3 dir,
						  float3 pos, float3 eye) {
	float ndl = dot(nml = normalize(nml),
					dir = normalize(dir));
	if (ndl <= 0)
		return 0;
	float3 v = normalize(eye - pos);
	float3 h = normalize(dir + v);
	float ndv = dot(nml, v);
	float ndh = dot(nml, h);
	float vdh = dot(v, h);
	float3 fd = mix(alb, 0.0f, mtl) * DIFF / M_PI_F;
	float3 f0 = mix(DIAL, alb, mtl);
	float rsq = rgh * rgh;
	float asq = rsq * rsq;
	float c = 1.0f + ndh * ndh * (asq - 1.0f);
	float D = step(0.0f, ndh) * asq / (M_PI_F * c * c);
	float G = G1(asq, ndl) * G1(asq, ndv);
	float3 F = f0 + (1.0f - f0) * powr(1.0f - abs(vdh), 5.0f);
	float3 fs = (D * G * F) / (4.0f * ndl * abs(ndv));
	return max(0.0f, ndl * (fs + fd));
}

fragment ldst frg_light(gbuf buf,
						const lpix pix					[[stage_in]],
						constant light *lgts			[[buffer(2)]],
						constant float4x4 &inv			[[buffer(3)]],
						constant float3 &eye			[[buffer(4)]],
						constant uint2 &res				[[buffer(5)]]) {
	
	float3 alb = (float3)buf.alb.rgb; float rgh = buf.alb.a;
	float3 nml = (float3)buf.nml.xyz; float mtl = buf.nml.a;
	float dep = buf.dep.x;
	float shd = buf.dep.y;
	
	float3 ndc = float3(pix.loc.x * 2/(float)res.x - 1,
						1 - pix.loc.y * 2/(float)res.y,
						dep);
	float4 wld = inv * float4(ndc, 1);
	float3 pos = wld.xyz / wld.w;
	
	light lgt = lgts[pix.iid];
	float3 hue = lgt.hue;
	float3 dir = lgt.pos;
	
	float lit = 1 - shd;
	if (!lgt.rad)
		buf.dst.rgb += half3(AMBI * hue * alb);
	else {
		float sqd = length_squared(dir -= pos);
		float sqr = lgt.rad * lgt.rad;
		if (sqd > sqr)
			return {buf.dst};
		float att = 1 - sqrt(sqd/sqr);
		lit *= att * att;
	}
	if (!lit)
		return {buf.dst};
	
	float3 rgb = lit * hue * BDRF(rgh, mtl, alb, nml, dir, pos, eye);
	buf.dst.rgb += (half3)rgb;
	return {buf.dst};
	
}
