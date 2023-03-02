#include <metal_stdlib>
using namespace metal;


typedef   depth2d<float, access::sample> depmap2f;
typedef texture2d<float, access::sample> texmap2f;
typedef texture2d< half, access::sample> texmap2h;


typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
} ldst;
typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
	half4 alb [[color(1), raster_order_group(1)]];
	half4 nml [[color(2), raster_order_group(1)]];
	half4 mat [[color(3), raster_order_group(1)]];
	float2 dep [[color(4), raster_order_group(1)]];
} gbuf;
typedef struct {
	float4 loc [[position]];
	uint iid [[flat]];
} lpix;

typedef struct {
	packed_float3 pos;
	packed_float3 nml;
	packed_float4 tgt;
	packed_float2 tex;
} vtx;
typedef struct {
	float4 camloc [[position]];
	float4 lgtloc;
	float2 tex;
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
	float3 dir;
	float rad;
	float spr;
} light;
typedef struct {
	float4x4 sun_ctm;
	float4x4 cam_ctm;
	float4x4 cam_inv;
	float3 cam_pos;
} scene;

typedef struct {
	half rgh;
	half mtl;
	half  ao;
	half emm;
} material;


static inline float3 nmlbump(texmap2f nmlmap, float2 loc, float3 nml, float3 tgt, bool sgn) {
	constexpr sampler smp(address::repeat);
	if (is_null_texture(nmlmap))
		return normalize(nml);
	float3 btg = cross(nml, tgt);
	float3x3 tbn = {tgt, sgn ? -btg : btg, nml};
	return normalize(tbn * (nmlmap.sample(smp, loc).xyz * 2.f - 1.f));
}

static inline float pcfshade(depmap2f shdmap, float4 loc) {
	constexpr sampler smp(compare_func::greater);
	constexpr int m = 6;
	constexpr float k = 5.0f / (4*m*m);
	if (is_null_texture(shdmap))
		return 0;
	loc.xyz /= loc.w;
	loc.xy = 0.5f * float2(1.f + loc.x, 1.f - loc.y);
	int shd = 0;
	for (int x = -m; x < m; ++x)
		for (int y = -m; y < m; ++y)
			shd += shdmap.sample_compare(smp, loc.xy, loc.z, int2(x, y));
	return saturate(k * (float)shd);
}


vertex float4 vtx_shade(const device vtx *vtcs	[[buffer(0)]],
						constant model *mdls	[[buffer(1)]],
						constant scene &scn		[[buffer(3)]],
						uint vid				[[vertex_id]],
						uint iid				[[instance_id]]) {
	constant model &mdl = mdls[iid];
	vtx v = vtcs[vid];
	float4 pos = float4(v.pos, 1.f);
	return scn.sun_ctm * mdl.ctm * pos;
}

vertex frg vtx_main(const device vtx *vtcs		[[buffer(0)]],
					constant model *mdls		[[buffer(1)]],
					constant scene &scn			[[buffer(3)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	constant model &mdl = mdls[iid];
	vtx v = vtcs[vid];
	float4 pos = mdl.ctm * float4(v.pos, 1.f);
	return {
		.camloc = scn.cam_ctm * pos,
		.lgtloc = scn.sun_ctm * pos,
		.tex = v.tex,
		.nml = normalize(mdl.inv * float3(v.nml)),
		.tgt = normalize(mdl.inv * float3(v.tgt.xyz)),
		.sgn = v.tgt.w < 0.f,
	};
}

fragment gbuf frg_gbuf(const frg f		[[stage_in]],
					   depmap2f shdmap	[[texture(0)]],
					   texmap2f albmap	[[texture(1)]],
					   texmap2f nmlmap	[[texture(2)]],
					   texmap2f rghmap	[[texture(3)]],
					   texmap2f mtlmap	[[texture(4)]],
					   texmap2f  aomap	[[texture(5)]],
					   texmap2f emmmap	[[texture(6)]]) {
	constexpr sampler smp(address::repeat);
	float3 alb = !is_null_texture(albmap)? albmap.sample(smp, f.tex).rgb : 1.f;
	half rgh = !is_null_texture(rghmap)? rghmap.sample(smp, f.tex).r : 1.h;
	half mtl = !is_null_texture(mtlmap)? mtlmap.sample(smp, f.tex).r : 0.h;
	half  ao = !is_null_texture( aomap)?  aomap.sample(smp, f.tex).r : 1.h;
	half emm = !is_null_texture(emmmap)? emmmap.sample(smp, f.tex).r : 0.1h;
	float3 nml = nmlbump(nmlmap, f.tex, f.nml, f.tgt, f.sgn);
	float shd = pcfshade(shdmap, f.lgtloc);
	float dep = f.camloc.z;
	return {
		.dst = 0.0h,
		.alb = half4((half3)alb, 0),
		.nml = half4((half3)nml, 0),
		.mat = half4(rgh, mtl, ao, emm),
		.dep = float2(dep, shd),
	};
}


vertex lpix vtx_quad(const device packed_float3 *vtcs	[[buffer(0)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float3 pos = vtcs[vid];
	float4 loc = float4(pos, 1.f);
	return {.loc = loc, .iid = iid};
}
vertex lpix vtx_icos(const device packed_float3 *vtcs	[[buffer(0)]],
					 constant light *lgts				[[buffer(2)]],
					 constant scene &scn				[[buffer(3)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	light lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * v;
	float4 loc = scn.cam_ctm * float4(pos, 1.f);
	return {.loc = loc, .iid = iid};
}
vertex float4 vtx_mask(const device packed_float3 *vtcs	[[buffer(0)]],
					   constant light *lgts				[[buffer(2)]],
					   constant scene &scn				[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	light lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * v;
	float4 loc = scn.cam_ctm * float4(pos, 1.f);
	return loc;
}


static inline float3 L(float3 alb, float mtl, float ao) {
	return ao * mix(alb, 0.f, mtl) / M_PI_F;
}
static inline float D(float ndh, float asq) {
	float c = 1.f + (asq - 1.f) * (ndh*ndh);
	return asq / (M_PI_F*c*c);
}
static inline float G1(float ndx, float asq) {
	float sq = ndx * ndx;
	float rt = sqrt(sq + asq * (1.f - sq));
	return 2.f * ndx / (ndx + rt);
}
static inline float G(float ndl, float ndv, float asq) {
	return G1(ndl, asq) * G1(ndv, asq);
}
static inline float3 F(float vdh, float3 f0) {
	return f0 + (1.f - f0) * powr(1.f - vdh, 5.f);
}
static float3 BDRF(material mat, float3 alb, float3 n, float3 l, float3 v) {
	constexpr float basef0 = 0.04f;
	
	float ndl = dot(n, l);
	if (ndl <= 0.f)
		return 0.f;
	
	float3 fd = ndl * L(alb, mat.mtl, mat.ao);
	
	float ndv = dot(n, v = normalize(v));
	if (ndv <= 0.f)
		return fd;
	float3 h = normalize(l + v);
	float ndh = dot(n, h);
	float vdh = dot(v, h);
	
	float asq = mat.rgh * mat.rgh;
	float3 fs = 0.25f / ndv;
	fs *= D(ndh, asq);
	fs *= G(ndl, ndv, asq);
	fs *= F(vdh, mix(basef0, alb, mat.mtl));
	
	return fd + fs;
	
}


// TODO: actually use the damn half4s
fragment ldst frg_light(const gbuf buf,
						const lpix pix			[[stage_in]],
						constant light *lgts	[[buffer(2)]],
						constant scene &scn		[[buffer(3)]],
						constant uint2 &res		[[buffer(4)]]) {
	if (length_squared(buf.dst.rgb) >= 3.f)
		return {1.h};
	
	float3 alb = (float3)buf.alb.rgb;
	float3 nml = (float3)buf.nml.xyz;
	float dep = buf.dep.x;
	float shd = buf.dep.y;
	material mat = {
		.rgh = buf.mat.r,
		.mtl = buf.mat.g,
		 .ao = buf.mat.b,
		.emm = buf.mat.a};
	
	float2 ndc = float2(pix.loc.x * 2.f/(float)res.x - 1.f,
						1.f - pix.loc.y * 2.f/(float)res.y);
	float4 wld = scn.cam_inv * float4(ndc, dep, 1.f);
	float3 pos = wld.xyz / wld.w;
	
	float3 eye = normalize(scn.cam_pos - pos);
	
	// don't think this is the way to go, but looks cool
	mat.ao *= saturate(1.f - shd);
	
	constant light &lgt = lgts[pix.iid];
	float3 rgb = lgt.hue;
	float3 dir;
	if (!lgt.rad)
		dir = normalize(lgt.dir);
	else {
		float sqd = length_squared(dir = lgt.pos - pos);
		float sqr = lgt.rad * lgt.rad;
		if (sqd >= sqr)
			return {buf.dst};
		rgb *= 1.f - sqd/sqr;
		dir = normalize(dir);
		if (lgt.spr) {
			float spr = 2.f * acos(dot(dir, lgt.dir));
			if (spr >= lgt.spr)
				return {buf.dst};
			rgb *= 1.f - spr/lgt.spr;
		}
	}
	
	rgb *= BDRF(mat, alb, nml, dir, eye);
	if (!lgt.rad)
		rgb += alb * mat.emm;
	
	return {half4(saturate((half3)rgb + buf.dst.rgb), buf.dst.a)};
	
}
