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
	packed_float4 tgt;
} vtx;
typedef struct {
	float4 camloc [[position]];
	float4 lgtloc;
	float2 texloc;
	float3 nml;
	float3 tgt;
	bool sgn [[flat]];
} frg;

typedef struct {
	float4x4 ctm;
	float3x3 inv;
} model;

typedef struct {
	float3 hue;
	float3 pos;
	float rad;
} light;


static inline float4 sample(texmap2 tex, float2 loc, float4 def = 1) {
	constexpr sampler smp(address::repeat);
	if (is_null_texture(tex))
		return def;
	return tex.sample(smp, loc);
}

static inline float3 bump(texmap2 nmlmap, float2 loc, float3 nml, float3 tgt, bool sgn) {
	constexpr sampler smp(address::repeat);
	if (is_null_texture(nmlmap))
		return nml;
	float3 btg = cross(nml, tgt);
	float3x3 tbn = {tgt, sgn ? -btg : btg, nml};
	return normalize(tbn * (nmlmap.sample(smp, loc).xyz * 2 - 1));
}

static inline float shade(depmap2 shdmap, float4 loc) {
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


vertex float4 vtx_shade(const device vtx *vtcs		[[buffer(0)]],
						constant model *mdls		[[buffer(1)]],
						constant float4x4 &lgtctm	[[buffer(2)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	constant model &mdl = mdls[iid];
	vtx v = vtcs[vid];
	float4 pos = float4(v.pos, 1);
	return lgtctm * mdl.ctm * pos;
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
	return {
		.camloc = camctm * pos,
		.lgtloc = lgtctm * pos,
		.texloc = v.tex,
		.nml = normalize(mdl.inv * float3(v.nml)),
		.tgt = normalize(mdl.inv * float3(v.tgt.xyz)),
		.sgn = v.tgt.w < 0,
	};
}

fragment gbuf frg_gbuf(const frg f					[[stage_in]],
					   depmap2 shdmap				[[texture(0)]],
					   texmap2 albmap				[[texture(1)]],
					   texmap2 nmlmap				[[texture(2)]],
					   texmap2 rghmap				[[texture(3)]],
					   texmap2 mtlmap				[[texture(4)]]) {
	float3 alb = sample(albmap, f.texloc, 1).rgb;
	float rgh = sample(rghmap, f.texloc, 1).r;
	float mtl = sample(mtlmap, f.texloc, 0).r;
	float3 nml = bump(nmlmap, f.texloc, f.nml, f.tgt, f.sgn);
	float shd = shade(shdmap, f.lgtloc);
	float dep = f.camloc.z;
	return {
		.dst = 0,
		.alb = half4((half3)alb, rgh),
		.nml = half4((half3)nml, mtl),
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


#define AMBIENT_SHADED		0.01f
#define F0_DIALECTRIC		0.04f
static inline float G1(float asq, float ndx) {
	float csq = ndx * ndx;
	float tsq = (1.0f - csq) / csq;
	return 2.0f / (1.0f + sqrt(1.0f + asq * tsq));
	
}
static float3 BDRF(float rgh,
				   float mtl,
				   float3 alb,
				   float3 nml, float3 dir,
				   float3 pos, float3 eye) {
	
	float3 v = normalize(eye - pos);
	float3 h = normalize(dir + v);
	float ndl = dot(nml = normalize(nml),
					dir = normalize(dir));
	float ndv = dot(nml, v);
	float ndh = dot(nml, h);
	float vdh = dot(v, h);
	
	float3 fd = mix(alb, 0.0f, mtl) / M_PI_F;
	float3 f0 = mix(F0_DIALECTRIC, alb, mtl);
	float asq = rgh * rgh;
	float c = (ndh * ndh) * (asq - 1.0f) + 1.0f;
	float d = step(0.0f, ndh) * asq / (M_PI_F * (c * c));
	float g = G1(asq, ndl) * G1(asq, ndv);;
	float3 f = f0 + (1.0f - f0) * powr(1.0f - abs(vdh), 5.0f);
	float3 fs = (d * g * f) / (4.0f * abs(ndl) * abs(ndv));
	return saturate(ndl) * (fd + fs);
	
}

fragment ldst frg_light(const gbuf buf,
						const lpix pix					[[stage_in]],
						constant light *lgts			[[buffer(2)]],
						constant float4x4 &inv			[[buffer(3)]],
						constant float3 &eye			[[buffer(4)]],
						constant uint2 &res				[[buffer(5)]]) {
	float4 dst = (float4)buf.dst;
	
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
	
	float lit = 0;
	if (!lgt.rad) {
		dst.rgb += AMBIENT_SHADED * hue * alb;
		lit = 1 - shd;
	}
	else {
		float sqd = length_squared(dir -= pos);
		float sqr = lgt.rad * lgt.rad;
		if (sqd > sqr)
			return {(half4)dst};
		float att = 1 - sqrt(sqd/sqr);
		lit = att * att;
	}
	if (!lit)
		return {buf.dst};
	
	hue *= BDRF(rgh, mtl, alb, nml, dir, pos, eye);
	dst.rgb += saturate(lit * hue);
	return {(half4)dst};
	
}
