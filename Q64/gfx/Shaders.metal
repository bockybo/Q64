#include <metal_stdlib>
using namespace metal;


typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
} lfrg;
typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
	half4 alb [[color(1), raster_order_group(1)]];
	half4 nml [[color(2), raster_order_group(1)]];
	half4 mat [[color(3), raster_order_group(1)]];
	float dep [[color(4), raster_order_group(1)]];
} gbuf;

typedef struct {
	packed_float3 pos;
	packed_float3 nml;
	packed_float4 tgt;
	packed_float2 tex;
} vtx;
typedef struct {
	float4 screen [[position]];
	float2 tex;
	float3 nml;
	float3 tgt;
	bool sgn [[flat]];
} frg;

typedef struct {
	float4 loc [[position]];
	uint aid [[render_target_array_index]];
} svtx;

typedef struct {
	float4 loc [[position]];
	uint iid [[flat]];
} lvtx;

typedef struct {
	float4x4 ctm;
	float3x3 inv;
} model;
typedef struct {
	float4x4 ctm;
	float3 hue;
	float3 pos;
	float3 dir;
	float rad;
	float fov;
} light;
typedef struct {
	float4x4 ctm;
	float4x4 inv;
	float3 pos;
} scene;

typedef struct {
	half rgh;
	half mtl;
	half  ao;
	half emm;
} material;


static inline float3 mmuldw(float4x4 mat, float3 vec) {
	float4 v4 = mat * float4(vec, 1.f);
	return v4.xyz / v4.w;
}

static inline float3 nmlbump(texture2d<float> nmlmap, float2 loc, float3 nml, float3 tgt, bool sgn) {
	constexpr sampler smp(address::repeat);
	if (is_null_texture(nmlmap))
		return normalize(nml);
	float3 btg = cross(nml, tgt);
	float3x3 tbn = {tgt, sgn ? -btg : btg, nml};
	return normalize(tbn * (nmlmap.sample(smp, loc).xyz * 2.f - 1.f));
}

static float pcfshadow(depth2d_array<float> shdmap, float4x4 ctm, float3 pos, uint iid, int m = 0) {
	constexpr sampler smp(compare_func::greater);
	float3 loc = mmuldw(ctm, pos);
	if (any((loc.xyz >= 1.f) || (loc.xyz <= float3(-1.f, -1.f, 0.f))))
		return 0.f;
	float2 uv = 0.5f * float2(1.f + loc.x, 1.f - loc.y);
	float dep = loc.z;
	if (!m)
		return shdmap.sample_compare(smp, uv, iid, dep);
	int shd = 0;
	for (int x = -m; x <= m; ++x)
		for (int y = -m; y <= m; ++y)
			shd += shdmap.sample_compare(smp, uv, iid, dep, int2(x, y));
	return (float)shd / (4*m*m);
}
// xyz: direction, w: attenuation
typedef float4 (*attenuator)(constant light &lgt, depth2d_array<float> shdmap, float3 pos, uint iid);
static float4 attenuate_quad(constant light &lgt, depth2d_array<float> shdmap, float3 pos, uint iid) {
	return float4(-lgt.dir, 1.f - pcfshadow(shdmap, lgt.ctm, pos, iid, 3));
}
static float4 attenuate_icos(constant light &lgt, depth2d_array<float> shdmap, float3 pos, uint iid) {
	float3 dir = lgt.pos - pos;
	float sqd = length_squared(dir);
	float sqr = lgt.rad * lgt.rad;
	return float4(normalize(dir), 1.f - sqd/sqr);
}
static float4 attenuate_spot(constant light &lgt, depth2d_array<float> shdmap, float3 pos, uint iid) {
	float4 att = attenuate_icos(lgt, shdmap, pos, iid);
	if (att.w <= 0.f)
		return 0.f;
	float d = dot(att.xyz, -lgt.dir);
	float fov = (d <= 0.f)? lgt.fov : (2.f * acos(d));
	if (fov >= lgt.fov)
		return 0.f;
	att.w *= 1.f - fov/lgt.fov;
	att.w *= 1.f - pcfshadow(shdmap, lgt.ctm, pos, iid);
	return att;
}
static float4 attenuate_gen(constant light &lgt, depth2d_array<float> shdmap, float3 pos, uint iid) {
	if (!lgt.rad) return attenuate_quad(lgt, shdmap, pos, iid);
	if (!lgt.fov) return attenuate_icos(lgt, shdmap, pos, iid);
	return attenuate_spot(lgt, shdmap, pos, iid);
}

static inline float3 L(float3 alb, float mtl, float ao) {
	return ao * mix(alb, 0.f, mtl) / M_PI_F;
}
static inline float D(float ndh, float asq) {
	float c = max(1e-3f, 1.f + (asq - 1.f) * (ndh*ndh));
	return asq / (M_PI_F*c*c);
}
static inline float G1(float ndx, float ad2) {
	return 1.f / (ndx * (1.f - ad2) + ad2);
}
static inline float G(float ndl, float ndv, float asq) {
	return G1(ndl, asq) * G1(ndv, asq);
}
static inline float3 F(float vdh, float3 f0) {
	return f0 + (1.f - f0) * powr(1.f - vdh, 5.f);
}
static float3 BDRF(material mat, float3 alb, float3 n, float3 l, float3 v) {
	constexpr float basef0 = 0.04f;
	
	float ndl = max(0.f, dot(n, l));
	float ndv = max(0.f, dot(n, v = normalize(v)));
	float3 fd = ndl * L(alb, mat.mtl, mat.ao);
	if (!(ndl && ndv))
		return fd;
	
	float3 h = normalize(l + v);
	float ndh = dot(n, h);
	float vdh = dot(v, h);

	float3 fs = 0.25f / ndv;
	fs *= D(ndh, mat.rgh * mat.rgh);
	fs *= G(ndl, ndv, 0.5f*mat.rgh);
	fs *= F(vdh, mix(basef0, alb, mat.mtl));

	return fd + fs;

}

// TODO: actually use the damn half4s
static lfrg com_light(const gbuf buf,
					  const lvtx pix,
					  constant light *lgts,
					  constant scene &cam,
					  depth2d_array<float> shdmap,
					  attenuator attenuate) {
	if (all(buf.dst.rgb >= 1.h))
		return {1.h};
	
	float3 alb = (float3)buf.alb.rgb;
	float3 nml = (float3)buf.nml.xyz;
	float dep = buf.dep;
	material mat = {
		.rgh = buf.mat.r,
		.mtl = buf.mat.g,
		.ao = buf.mat.b,
		.emm = buf.mat.a};
	
	float3 pos = mmuldw(cam.inv, float3(pix.loc.xy, dep));
	
	constant light &lgt = lgts[pix.iid];
	float4 att = attenuate(lgt, shdmap, pos, pix.iid);
	if (att.a <= 0.f)
		return {buf.dst};
	float3 l = att.xyz;
	float3 v = normalize(cam.pos - pos);
	
	float3 rgb = att.a * lgt.hue * BDRF(mat, alb, nml, l, v);
	if (!lgt.rad)
		rgb += alb * mat.emm;
	
	return {half4(saturate((half3)rgb + buf.dst.rgb), buf.dst.a)};
	
}


vertex svtx vtx_shade(const device vtx *vtcs	[[buffer(0)]],
					  constant model *mdls		[[buffer(1)]],
					  constant light *lgts		[[buffer(2)]],
					  uint vid					[[vertex_id]],
					  uint iid					[[instance_id]],
					  uint aid					[[amplification_id]]) {
	constant model &mdl = mdls[iid];
	constant light &lgt = lgts[aid];
	vtx v = vtcs[vid];
	float4 pos = float4(v.pos, 1.f);
	float4 loc = lgt.ctm * mdl.ctm * pos;
	return {.loc = loc, .aid = aid};
}

vertex frg vtx_main(const device vtx *vtcs		[[buffer(0)]],
					constant model *mdls		[[buffer(1)]],
					constant scene &cam			[[buffer(3)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	constant model &mdl = mdls[iid];
	vtx v = vtcs[vid];
	float4 pos = mdl.ctm * float4(v.pos, 1.f);
	return {
		.screen = cam.ctm * pos,
		.tex = v.tex,
		.nml = normalize(mdl.inv * float3(v.nml)),
		.tgt = normalize(mdl.inv * float3(v.tgt.xyz)),
		.sgn = v.tgt.w < 0.f,
	};
}

fragment gbuf frg_gbuf(const frg f				[[stage_in]],
					   texture2d<float> albmap	[[texture(1)]],
					   texture2d<float> nmlmap	[[texture(2)]],
					   texture2d<float> rghmap	[[texture(3)]],
					   texture2d<float> mtlmap	[[texture(4)]],
					   texture2d<float>  aomap	[[texture(5)]],
					   texture2d<float> emmmap	[[texture(6)]]) {
	constexpr sampler smp(address::repeat);
	float3 alb = !is_null_texture(albmap)? albmap.sample(smp, f.tex).rgb : 1.f;
	half rgh = !is_null_texture(rghmap)? rghmap.sample(smp, f.tex).r : 1.h;
	half mtl = !is_null_texture(mtlmap)? mtlmap.sample(smp, f.tex).r : 0.h;
	half  ao = !is_null_texture( aomap)?  aomap.sample(smp, f.tex).r : 1.h;
	half emm = !is_null_texture(emmmap)? emmmap.sample(smp, f.tex).r : 0.1h;
	float3 nml = nmlbump(nmlmap, f.tex, f.nml, f.tgt, f.sgn);
	float dep = f.screen.z;
	// really should think through formatting here
	return {
		.dst = 0.h,
		.alb = half4((half3)alb, 0.h),
		.nml = half4((half3)nml, 0.h),
		.mat = half4(rgh, mtl, ao, emm),
		.dep = dep
	};
}


vertex lvtx vtx_quad(const device packed_float3 *vtcs	[[buffer(0)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	float4 loc = float4(vtcs[vid], 1.f);
	return {.loc = loc, .iid = iid};
}

vertex lvtx vtx_icos(const device packed_float3 *vtcs	[[buffer(0)]],
					 constant light *lgts				[[buffer(2)]],
					 constant scene &cam				[[buffer(3)]],
					 uint vid							[[vertex_id]],
					 uint iid							[[instance_id]]) {
	constant light &lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * vtcs[vid];
	float4 loc = cam.ctm * float4(pos, 1.f);
	return {.loc = loc, .iid = iid};
}
vertex float4 vtx_mask(const device packed_float3 *vtcs	[[buffer(0)]],
					   constant light *lgts				[[buffer(2)]],
					   constant scene &cam				[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	constant light &lgt = lgts[iid];
	float3 pos = lgt.pos + lgt.rad * vtcs[vid];
	float4 loc = cam.ctm * float4(pos, 1.f);
	return loc;
}

fragment lfrg frg_light(const gbuf buf,
						const lvtx pix					[[stage_in]],
						constant light *lgts			[[buffer(2)]],
						constant scene &cam				[[buffer(3)]],
						depth2d_array<float> shdmap 	[[texture(0)]]) {
	return com_light(buf, pix, lgts, cam, shdmap, attenuate_gen);
}

fragment lfrg frg_quad(const gbuf buf,
					   const lvtx pix				[[stage_in]],
					   constant light *lgts			[[buffer(2)]],
					   constant scene &cam			[[buffer(3)]],
					   depth2d_array<float> shdmap 	[[texture(0)]]) {
	return com_light(buf, pix, lgts, cam, shdmap, attenuate_quad);
}
fragment lfrg frg_icos(const gbuf buf,
					   const lvtx pix				[[stage_in]],
					   constant light *lgts			[[buffer(2)]],
					   constant scene &cam			[[buffer(3)]],
					   depth2d_array<float> shdmap 	[[texture(0)]]) {
	return com_light(buf, pix, lgts, cam, shdmap, attenuate_icos);
}
fragment lfrg frg_spot(const gbuf buf,
					   const lvtx pix				[[stage_in]],
					   constant light *lgts			[[buffer(2)]],
					   constant scene &cam			[[buffer(3)]],
					   depth2d_array<float> shdmap 	[[texture(0)]]) {
	return com_light(buf, pix, lgts, cam, shdmap, attenuate_spot);
}
