#include <metal_stdlib>
using namespace metal;


#define DEBUGMASK 	0

#define NMATERIAL	32
#define BASE_F0		0.04f

#define MPCF		4
#define ZSHADOW		1e-5f


typedef struct {
	half4 dst [[color(0), raster_order_group(0)]];
} lpix;
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
	float4 loc [[position]];
	float3 pos;
	float2 tex;
	half3 nml;
	half3 tgt;
	half3 btg;
	uint mat [[flat]];
} frg;

typedef struct {
	float4 loc [[position]];
	uint lid [[render_target_array_index]];
} sfrg;

typedef struct {
	float4 loc [[position]];
	uint lid [[flat]];
} lfrg;

// for dev clarity, tmp keep proj & view seperate
// but pack before bind down the road
typedef struct {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	uint2 res;
} camera;
typedef struct {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	float3 hue;
	float phi;
} light;

typedef struct {
	float4x4 ctm;
	float3x3 nml;
	uint mat;
} model;

typedef struct {
	half3 alb;
	half3 nml;
	half  rgh;
	half  mtl;
	half   ao;
} material;
typedef struct {
	texture2d<half> alb	[[texture(0)]];
	texture2d<half> nml	[[texture(1)]];
	texture2d<half> rgh	[[texture(2)]];
	texture2d<half> mtl	[[texture(3)]];
	texture2d<half>  ao	[[texture(4)]];
	float3 alb_default	[[id(5)]];
	float3 nml_default	[[id(6)]];
	float  rgh_default	[[id(7)]];
	float  mtl_default	[[id(8)]];
	float   ao_default	[[id(9)]];
} modelmaterial;
typedef array<modelmaterial, NMATERIAL> materialbuf;


static inline float3 mmulw(float4x4 mat, float4 vec) {
	float4 ret = mat * vec;
	return ret.xyz / ret.w;
}
static inline float3 mmulw(float4x4 mat, float3 vec) {
	return mmulw(mat, float4(vec, 1.f));
}

static inline float3 mpos(float4x4 mat) {return  mat[3].xyz;}
static inline float3 mdir(float4x4 mat) {return -mat[2].xyz;}
static inline float msqd(float4x4 mat) {return length_squared(mdir(mat));}

static inline float3 loc2wld(float4x4 ctm, float3 loc) {
	loc.xy *= 2.f;
	loc.x = loc.x - 1.f;
	loc.y = 1.f - loc.y;
	return mmulw(ctm, loc);
}
static inline float3 wld2loc(float4x4 ctm, float3 wld) {
	wld = mmulw(ctm, wld);
	wld.x = 1.f + wld.x;
	wld.y = 1.f - wld.y;
	wld.xy *= 0.5f;
	return wld;
}

static inline half3 smpdefault(sampler smp, texture2d<half> tex, float2 uv, half3 def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).rgb);
}
static inline half smpdefault(sampler smp, texture2d<half> tex, float2 uv, half def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).r);
}
static inline half3 tbnx(half3 nml, half3x3 tbn) {
	return normalize(tbn * normalize(nml * 2.h - 1.h));
}
static inline material matsample(const frg f, constant materialbuf &materials) {
	constexpr sampler smp(address::repeat);
	constant modelmaterial &mmat = materials[f.mat];
	material mat;
	mat.alb = smpdefault(smp, mmat.alb, f.tex, (half3)mmat.alb_default);
	mat.nml = smpdefault(smp, mmat.nml, f.tex, (half3)mmat.nml_default);
	mat.rgh = smpdefault(smp, mmat.rgh, f.tex,  (half)mmat.rgh_default);
	mat.mtl = smpdefault(smp, mmat.mtl, f.tex,  (half)mmat.mtl_default);
	mat. ao = smpdefault(smp, mmat. ao, f.tex,  (half)mmat. ao_default);
	mat.nml = tbnx(mat.nml, {f.tgt, f.btg, f.nml});
	return mat;
}

static inline float smpshadowpcf(float3 pos, light lgt, depth2d_array<float> shdmaps, uint lid) {
	constexpr sampler smp;
	float3 loc = wld2loc(lgt.proj * lgt.invview, pos);
	float z = loc.z - ZSHADOW;
	int shd = 0;
	for (int x = 0; x < MPCF; ++x)
		for (int y = 0; y < MPCF; ++y)
			shd += z > shdmaps.sample(smp, loc.xy, lid, int2(x, y) - MPCF/2);
	return (float)shd / (MPCF*MPCF);
}

static inline float3 L(float3 alb, float mtl, float ao) {
	return ao * mix(alb, 0.f, mtl) / M_PI_F;
}
static inline float D(float asq, float ndh) {
	float c = max(1e-3f, 1.f + (asq - 1.f) * (ndh*ndh));
	return step(0.f, ndh) * asq / (M_PI_F*c*c);
}
static inline float G1(float asq, float ndx) {
	float csq = ndx * ndx;
	float tsq = (1.0f - csq) / max(csq, 1e-4);
	return 2.0f / (1.0f + sqrt(1.0f + asq * tsq));
}
static inline float G(float asq, float ndl, float ndv) {
	return G1(asq, ndl) * G1(asq, ndv);
}
static inline float3 F(float vdh, float3 f0) {
	return f0 + (1.f - f0) * powr(1.f - abs(vdh), 5.f);
}
static float3 BDRF(material mat, float3 l, float3 v) {
	float3 n = (float3)normalize(mat.nml);
	float ndl = dot(n, l);
	if (ndl <= 0.f)
		return 0.f;
	float ndv = dot(n, v);
	float3 h = normalize(l + v);
	float ndh = dot(n, h);
	float vdh = dot(v, h);
	float3 fd = L((float3)mat.alb, (float)mat.mtl, (float)mat.ao);
	float3 fs = 0.25f / abs(ndl * ndv);
	float asq = mat.rgh * mat.rgh;
	fs *= D(asq, ndh);
	fs *= G(asq, ndl, ndv);
	fs *= F(vdh, mix(BASE_F0, (float3)mat.alb, (float)mat.mtl));
	return ndl * (fd + fs);
}

// xyz: normalized direction, w: attenuation
// TODO: use actual visible function pointers
typedef float4 (*attenuator)(float3 pos, light lgt, depth2d_array<float> shdmaps, uint lid);
static float4 attenuate_quad(float3 pos, light lgt, depth2d_array<float> shdmaps, uint lid) {
	float3 dir = normalize(mdir(lgt.view));
	float  shd = smpshadowpcf(pos, lgt, shdmaps, lid);
	return float4(-dir, 1.f - shd);
}
static float4 attenuate_icos(float3 pos, light lgt, depth2d_array<float> shdmaps, uint lid) {
	float3 dir = mpos(lgt.view) - pos;
	float sqr = msqd(lgt.view);
	float sqd = length_squared(dir);
	return float4(normalize(dir), 1.f - sqd/sqr);
}
static float4 attenuate_cone(float3 pos, light lgt, depth2d_array<float> shdmaps, uint lid) {
	float4 att = attenuate_icos(pos, lgt, shdmaps, lid);
	if (att.a <= 0.f) // avoid acos if possible
		return 0.f;
	float3 dir = normalize(mdir(lgt.view));
	float  phi = acos(dot(att.xyz, -dir));
	if (phi >= lgt.phi) // avoid shadow smp; TODO: research tradeoff for the branch
		return 0.f;
	att.a *= 1.f - phi/lgt.phi;
	att.a *= 1.f - smpshadowpcf(pos, lgt, shdmaps, lid);
	return att;
}

static half3 com_lighting(material mat,
						  float3 p,
						  float3 v,
						  uint lid,
						  const device light *lgts,
						  depth2d_array<float> shdmaps,
						  attenuator attenuate) {
#if DEBUGMASK
	if (attenuate != attenuate_quad)
		return (half3)normalize(lgts[lid].hue) * 0.2h;
#endif
	light lgt = lgts[lid];
	float4 att = attenuate(p, lgt, shdmaps, lid);
	if (att.a <= 0.f)
		return 0.h;
	lgt.hue *= att.a;
	float3 l = att.xyz;
	return (half3)saturate(lgt.hue * BDRF(mat, l, v));
}

static lpix buf_lighting(const gbuf buf,
						 const lfrg pix,
						 constant camera &cam,
						 const device light *lgts,
						 depth2d_array<float> shdmaps,
						 attenuator attenuate) {
	float2 uv = pix.loc.xy;
	float3 ndc = float3(uv / (float2)cam.res, buf.dep);
	float3 pos = loc2wld(cam.view * cam.invproj, ndc);
	float3 v = normalize(mpos(cam.view) - pos);
	material mat = {
		.alb = buf.alb.rgb,
		.nml = buf.nml.xyz,
		.rgh = buf.mat.r,
		.mtl = buf.mat.g,
		. ao = buf.mat.b,
	};
	half3 rgb = com_lighting(mat, pos, v, pix.lid, lgts, shdmaps, attenuate);
	return {buf.dst + half4(rgb, 0.h)};
}


vertex sfrg vtx_shade(const device vtx *vtcs	[[buffer(0)]],
					  const device model *mdls	[[buffer(1)]],
					  const device light *lgts	[[buffer(2)]],
					  uint vid					[[vertex_id]],
					  uint iid					[[instance_id]],
					  uint lid					[[base_instance]]) {
	model mdl = mdls[iid - lid];
	light lgt = lgts[lid];
	float4 pos = mdl.ctm * float4(vtcs[vid].pos, 1.f);
	float4 loc = lgt.proj * lgt.invview * pos;
	return {.loc = loc, .lid = lid};
}

vertex frg vtx_main(const device vtx *vtcs		[[buffer(0)]],
					const device model *mdls	[[buffer(1)]],
					constant camera &cam		[[buffer(3)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	vtx v = vtcs[vid];
	model mdl = mdls[iid];
	float4 pos = mdl.ctm * float4(v.pos, 1.f);
	float4 loc = cam.proj * cam.invview * pos;
	half3 nml = (half3)normalize(mdl.nml * (float3)v.nml);
	half3 tgt = (half3)normalize(mdl.nml * (float3)v.tgt.xyz);
	half3 btg = cross(nml, tgt) * v.tgt.w;
	return {
		.loc = loc,
		.pos = pos.xyz,
		.tex = v.tex,
		.nml = nml,
		.tgt = tgt,
		.btg = btg,
		.mat = mdl.mat,
	};
}

fragment gbuf frg_gbuf(const frg f						[[stage_in]],
					   constant materialbuf &materials	[[buffer(0)]]) {
	material mat = matsample(f, materials);
	// TODO: need to actually pack this obv
	return {
		.dst = 0.h,
		.alb = half4((half3)mat.alb, 0.h),
		.nml = half4((half3)mat.nml, 0.h),
		.mat = half4(mat.rgh, mat.mtl, mat.ao, 0.h),
		.dep = f.loc.z,
	};
}

vertex lfrg vtx_quad(const device packed_float3 *vtcs		[[buffer(0)]],
					 const device light *lgts				[[buffer(2)]],
					 constant camera &cam					[[buffer(3)]],
					 uint vid								[[vertex_id]],
					 uint lid								[[instance_id]]) {
	float4 loc = float4(vtcs[vid], 1.f);
	return {.loc = loc, .lid = lid};
}
vertex lfrg vtx_volume(const device packed_float3 *vtcs		[[buffer(0)]],
					   const device light *lgts				[[buffer(2)]],
					   constant camera &cam					[[buffer(3)]],
					   uint vid								[[vertex_id]],
					   uint lid								[[instance_id]]) {
	light lgt = lgts[lid];
	float4 pos = lgt.view * float4(vtcs[vid], 1.f);
	float4 loc = cam.proj * cam.invview * pos;
	return {.loc = loc, .lid = lid};
}

fragment lpix frg_quad(const gbuf buf,
					   const lfrg pix					[[stage_in]],
					   const device light *lgts			[[buffer(2)]],
					   constant camera &cam				[[buffer(3)]],
					   depth2d_array<float> shdmaps		[[texture(0)]]) {
	return buf_lighting(buf, pix, cam, lgts, shdmaps, attenuate_quad);
}
fragment lpix frg_icos(const gbuf buf,
					   const lfrg pix					[[stage_in]],
					   const device light *lgts			[[buffer(2)]],
					   constant camera &cam				[[buffer(3)]],
					   depth2d_array<float> shdmaps		[[texture(0)]]) {
	return buf_lighting(buf, pix, cam, lgts, shdmaps, attenuate_icos);
}
fragment lpix frg_cone(const gbuf buf,
					   const lfrg pix					[[stage_in]],
					   const device light *lgts			[[buffer(2)]],
					   constant camera &cam				[[buffer(3)]],
					   depth2d_array<float> shdmaps		[[texture(0)]]) {
	return buf_lighting(buf, pix, cam, lgts, shdmaps, attenuate_cone);
}

fragment half4 frg_fwd(const frg f							[[stage_in]],
					   constant materialbuf &materials		[[buffer(0)]],
					   constant camera &cam					[[buffer(3)]],
					   depth2d_array<float> quad_shdmaps	[[texture(4)]],
					   depth2d_array<float> cone_shdmaps	[[texture(5)]],
					   depth2d_array<float> icos_shdmaps	[[texture(6)]],
					   const device light *quad_lgts		[[buffer(4)]],
					   const device light *cone_lgts		[[buffer(5)]],
					   const device light *icos_lgts		[[buffer(6)]],
					   constant int &nquad					[[buffer(7)]],
					   constant int &ncone					[[buffer(8)]],
					   constant int &nicos					[[buffer(9)]]) {
	material mat = matsample(f, materials);
	float3 p = f.pos;
	float3 v = normalize(mpos(cam.view) - p);
	half3 rgb = 0.h;
	for (int i = 0; i < nquad; ++i)
		rgb += com_lighting(mat, p, v, i, quad_lgts, quad_shdmaps, attenuate_quad);
	for (int i = 0; i < ncone; ++i)
		rgb += com_lighting(mat, p, v, i, cone_lgts, cone_shdmaps, attenuate_cone);
	for (int i = 0; i < nicos; ++i)
		rgb += com_lighting(mat, p, v, i, icos_lgts, icos_shdmaps, attenuate_icos);
	return half4(rgb, 1.h);
}
