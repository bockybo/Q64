#include <metal_stdlib>
using namespace metal;

#define DEBUGMASK 	0
#define MPCF		3
#define NSHADOW		128
#define ZSHADOW		5e-6f
#define BASE_F0		0.04f


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
	float4 loc [[position]];
	uint iid [[flat]];
} lfrg;

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
	float3 btg;
} frg;

typedef struct {
	float4x4 ctm;
	float3x3 nml;
} model;
typedef struct {
	float4x4 ctm;
	float4x4 inv;
	float3 hue;
	float phi;
} light;
typedef struct {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	uint2 res;
} camera;

typedef struct {
	float3 alb;
	float rgh;
	float mtl;
	float  ao;
} material;


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

float3 smpdefault(sampler smp, texture2d<half> tex, float2 uv, float3 def) {
	return saturate(is_null_texture(tex) ? def : (float3)tex.sample(smp, uv).rgb);
}
float smpdefault(sampler smp, texture2d<half> tex, float2 uv, float def) {
	return saturate(is_null_texture(tex) ? def : (float)tex.sample(smp, uv).r);
}

static inline half3 smpnormal(sampler smp, texture2d<half> nmlmap, const frg f) {
	if (is_null_texture(nmlmap))
		return (half3)f.nml;
	float3x3 tbn = {f.tgt, f.btg, f.nml};
	half3 nml = normalize(nmlmap.sample(smp, f.tex).xyz * 2.h - 1.h);
	return (half3)normalize(tbn * (float3)nml);
}

static float smpshadowpcf(depth2d<float> shdmap, constant light &lgt, float3 pos) {
	constexpr sampler smp;
	float3 loc = wld2loc(lgt.ctm, pos);
	float z = loc.z - ZSHADOW;
	int off = MPCF/2;
	int shd = 0;
	for (int x = 0; x < MPCF; ++x)
		for (int y = 0; y < MPCF; ++y)
			shd += z > shdmap.sample(smp, loc.xy, int2(x, y) - off);
	return (float)shd / (MPCF*MPCF);
}

// xyz: normalized direction, w: attenuation
typedef float4 (*attenuator)(constant light &lgt, float3 pos, depth2d<float> shdmap);
static float4 attenuate_quad(constant light &lgt, float3 pos, depth2d<float> shdmap) {
	float3 dir = normalize(mdir(lgt.inv));
	float  shd = smpshadowpcf(shdmap, lgt, pos);
	return float4(-dir, 1.f - shd);
}
static float4 attenuate_icos(constant light &lgt, float3 pos, depth2d<float> shdmap) {
	float3 dir = mpos(lgt.inv) - pos;
	float sqr = msqd(lgt.inv);
	float sqd = length_squared(dir);
	return float4(normalize(dir), 1.f - sqd/sqr);
}
static float4 attenuate_cone(constant light &lgt, float3 pos, depth2d<float> shdmap) {
	float4 att = attenuate_icos(lgt, pos, shdmap);
	if (att.w <= 0.f) // avoid acos if possible
		return 0.f;
	float3 dir = normalize(mdir(lgt.inv));
	float  phi = acos(dot(att.xyz, -dir));
	if (phi >= lgt.phi) // avoid shadow smp; TODO: research tradeoff for the branch
		return 0.f;
	att.w *= 1.f - phi/lgt.phi;
	att.w *= 1.f - smpshadowpcf(shdmap, lgt, pos);
	return att;
}

static inline float3 L(float3 alb, float mtl, float ao) {
	return ao * mix(alb, 0.f, mtl) / M_PI_F;
}
static inline float D(float asq, float ndh) {
	float c = max(1e-3f, 1.f + (asq - 1.f) * (ndh*ndh));
	return step(0.f, ndh) * asq / (M_PI_F*c*c);
}
//static inline float G1(float ad2, float ndx) {
//	return 1.f / (ndx * (1.f - ad2) + ad2);
//}
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
static float3 BDRF(material mat, float3 n, float3 l, float3 v) {
	float ndl = dot(n, l);
	float ndv = dot(n, v = normalize(v));
	float3 h = normalize(l + v);
	float ndh = dot(n, h);
	float vdh = dot(v, h);
	float3 fd = L(mat.alb, mat.mtl, mat.ao);
	float3 fs = 0.25f / abs(ndl * ndv);
	float asq = mat.rgh * mat.rgh;
	fs *= D(asq, ndh);
//	fs *= G(mat.rgh * 0.5f, ndl, ndv);
	fs *= G(asq, ndl, ndv);
	fs *= F(vdh, mix(BASE_F0, mat.alb, mat.mtl));
	return max(0.0f, ndl) * (fd + fs);
}

// TODO: actually use the damn half4s
static lpix com_lighting(const gbuf buf,
						 float2 uv,
						 constant camera &cam,
						 constant light &lgt,
						 depth2d<float> shdmap,
						 attenuator attenuate) {
#if DEBUGMASK
	return {buf.dst + half4((half3)normalize(lgts[pix.id].hue) * 0.5h, 0.h)};
#endif
	
	float3 n = (float3)buf.nml.xyz;
	material mat = {
		.alb = (float3)buf.alb.rgb,
		.rgh = buf.mat.r,
		.mtl = buf.mat.g,
		. ao = buf.mat.b};
	
	float3 ndc = float3(uv / (float2)cam.res, buf.dep);
	float3 pos = loc2wld(cam.view * cam.invproj, ndc);
	
	float4 att = attenuate(lgt, pos, shdmap);
	if (att.a <= 0.f)
		return {buf.dst};
	float3 l = att.xyz;
	float3 v = normalize(mpos(cam.view) - pos);
	
	float3 rgb = att.a * lgt.hue * BDRF(mat, n, l, v);
	return {buf.dst + half4((half3)rgb, 0.h)};
	
}


vertex float4 vtx_shade(const device vtx *vtcs	[[buffer(0)]],
						constant model *mdls	[[buffer(1)]],
						constant light &lgt		[[buffer(2)]],
						uint vid				[[vertex_id]],
						uint iid				[[instance_id]]) {
	return lgt.ctm * mdls[iid].ctm * float4(vtcs[vid].pos, 1.f);
}

vertex frg vtx_main(const device vtx *vtcs		[[buffer(0)]],
					constant model *mdls		[[buffer(1)]],
					constant camera &cam		[[buffer(3)]],
					uint vid					[[vertex_id]],
					uint iid					[[instance_id]]) {
	constant model &mdl = mdls[iid];
	
	vtx v = vtcs[vid];
	float4 pos = mdl.ctm * float4(v.pos, 1.f);
	
	float3 nml = normalize(mdl.nml * float3(v.nml));
	float3 tgt = normalize(mdl.nml * float3(v.tgt.xyz));
	float3 btg = cross(nml, tgt) * v.tgt.w;
	
	return {
		.screen = cam.proj * cam.invview * pos,
		.tex = v.tex,
		.nml = nml,
		.tgt = tgt,
		.btg = btg,
	};
	
}

fragment gbuf frg_gbuf(const frg f				[[stage_in]],
					   constant material &mat	[[buffer(0)]],
					   texture2d<half> albmap	[[texture(0)]],
					   texture2d<half> nmlmap	[[texture(1)]],
					   texture2d<half> rghmap	[[texture(2)]],
					   texture2d<half> mtlmap	[[texture(3)]],
					   texture2d<half>  aomap	[[texture(4)]]) {
	constexpr sampler smp(address::repeat);
	
	float dep = f.screen.z;
	half3 nml = smpnormal(smp, nmlmap, f);
	
	half3 alb = (half3)smpdefault(smp, albmap, f.tex, mat.alb);
	half rgh  = (half)smpdefault(smp, rghmap, f.tex, mat.rgh);
	half mtl  = (half)smpdefault(smp, mtlmap, f.tex, mat.mtl);
	half  ao  = (half)smpdefault(smp,  aomap, f.tex, mat.ao);
	
	// really should think through formatting here
	return {
		.dst = 0.h,
		.alb = half4(alb, 0.h),
		.nml = half4(nml, 0.h),
		.mat = half4(rgh, mtl, ao, 0.h),
		.dep = dep
	};
	
}

vertex lfrg vtx_quad(const device packed_float3 *vtcs	[[buffer(0)]],
					 uint vid							[[vertex_id]]) {
	return {.loc = float4(vtcs[vid], 1.f), .iid = 0};
}

vertex float4 vtx_mask(const device packed_float3 *vtcs	[[buffer(0)]],
					   constant light *lgts				[[buffer(2)]],
					   constant camera &cam				[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	constant light &lgt = lgts[iid];
	float4 pos = lgt.inv * float4(vtcs[vid], 1.f);
	float4 loc = cam.proj * cam.invview * float4(pos.xyz, 1.f);
	return loc;
}
vertex lfrg vtx_light(const device packed_float3 *vtcs	[[buffer(0)]],
					  constant light *lgts				[[buffer(2)]],
					  constant camera &cam				[[buffer(3)]],
					  uint vid							[[vertex_id]],
					  uint iid							[[instance_id]]) {
	constant light &lgt = lgts[iid];
	float4 pos = lgt.inv * float4(vtcs[vid], 1.f);
	float4 loc = cam.proj * cam.invview * float4(pos.xyz, 1.f);
	return {.loc = loc, .iid = iid};
}

fragment lpix frg_quad(const gbuf buf,
					   const lfrg pix							[[stage_in]],
					   constant light *lgts						[[buffer(2)]],
					   constant camera &cam						[[buffer(3)]],
					   array<depth2d<float>, NSHADOW> shdmaps 	[[texture(0)]]) {
	return com_lighting(buf, pix.loc.xy, cam, lgts[pix.iid], shdmaps[pix.iid], attenuate_quad);
}
fragment lpix frg_icos(const gbuf buf,
					   const lfrg pix							[[stage_in]],
					   constant light *lgts						[[buffer(2)]],
					   constant camera &cam						[[buffer(3)]],
					   array<depth2d<float>, NSHADOW> shdmaps 	[[texture(0)]]) {
	return com_lighting(buf, pix.loc.xy, cam, lgts[pix.iid], shdmaps[pix.iid], attenuate_icos);
}
fragment lpix frg_cone(const gbuf buf,
					   const lfrg pix							[[stage_in]],
					   constant light *lgts						[[buffer(2)]],
					   constant camera &cam						[[buffer(3)]],
					   array<depth2d<float>, NSHADOW> shdmaps 	[[texture(0)]]) {
	return com_lighting(buf, pix.loc.xy, cam, lgts[pix.iid], shdmaps[pix.iid], attenuate_cone);
}
