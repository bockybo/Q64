#include <metal_stdlib>
using namespace metal;


#define DEBUGMASK 	0
#define DEBUGCULL	0

#define NMATERIAL	32
#define BASE_F0		0.04h

#define NPCF		4
#define ZSHADOW		5e-5f


struct cpix {
	half4 color 	[[raster_order_group(0), color(0)]];
};
struct dpix {
	half4 color 	[[raster_order_group(0), color(0)]];
	float depth 	[[raster_order_group(1), color(1)]];
};
struct gbuf {
	half4 color 	[[raster_order_group(0), color(0)]];
	float depth 	[[raster_order_group(1), color(1)]];
	half4 alb		[[raster_order_group(1), color(2)]];
	half4 nml		[[raster_order_group(1), color(3)]];
	half4 mat		[[raster_order_group(1), color(4)]];
};

using  pvtx = packed_float3;
struct mvtx {
	packed_float3 pos;
	packed_float3 nml;
	packed_float4 tgt;
	packed_float2 tex;
};
struct mfrg {
	float4 loc [[position]];
	float3 pos;
	float2 tex;
	half3 nml;
	half3 tgt;
	half3 btg;
	uint mat [[flat]];
};

struct lfrg {
	float4 loc [[position]];
	uint lid [[flat]];
};

// for dev clarity, tmp keep proj & view seperate
// but pack before bind down the road
struct camera {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	uint2 res;
};
struct light {
	float4x4 proj;
	float4x4 view;
	float4x4 invproj;
	float4x4 invview;
	float3 hue;
	float phi;
};
using shadowmaps = depth2d_array<float>;

struct scene {
	uint nlgt;
	camera cam;
};

struct model {
	float4x4 ctm;
	float4x4 inv;
	uint mat;
};

struct material {
	half3 alb;
	half3 nml;
	half  rgh;
	half  mtl;
	half   ao;
};
struct modelmaterial {
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
};
using materialbuf = array<modelmaterial, NMATERIAL>;

struct frustum {
	float4 planes[6];
	float3 points[8]; // TODO: use for aabb?
};

struct tile {
	atomic_uint msk;
	float mindepth;
	float maxdepth;
};


inline float4 mmul4(float4x4 mat, float4 vec) {return mat * vec;}
inline float3 mmul3(float4x4 mat, float4 vec) {return (mat * vec).xyz;}
inline float4 mmul4w(float4x4 mat, float4 vec) {float4 r = mat * vec; return r / r.w;}
inline float3 mmul3w(float4x4 mat, float4 vec) {float4 r = mat * vec; return r.xyz / r.w;}
inline float4 mmul4(float4x4 mat, float3 vec, float w = 1.f) {return mmul4(mat, float4(vec, w));}
inline float3 mmul3(float4x4 mat, float3 vec, float w = 1.f) {return mmul3(mat, float4(vec, w));}
inline float4 mmul4w(float4x4 mat, float3 vec, float w = 1.f) {return mmul4w(mat, float4(vec, w));}
inline float3 mmul3w(float4x4 mat, float3 vec, float w = 1.f) {return mmul3w(mat, float4(vec, w));}

inline float2 loc2ndc(float2 loc) {return float2((2.0f * loc.x) - 1.0f, 1.0f - (2.0f * loc.y));}
inline float2 ndc2loc(float2 ndc) {return float2((1.0f + ndc.x) * 0.5f, 0.5f * (1.0f - ndc.y));}

inline float3 viewpos(float4x4 view) {return view[3].xyz;}
inline float3 viewdlt(float4x4 view) {return view[2].xyz;}
inline float3 viewdir(float4x4 view) {return normalize(viewdlt(view));}
inline float viewsqd(float4x4 view) {return length_squared(viewdlt(view));}
inline float viewlen(float4x4 view) {return length(viewdlt(view));}


static inline half3 debug_mask(light lgt) {
	return (half3)normalize(lgt.hue) * 0.2h;
}
static inline cpix debug_cull(uint msk) {
	constexpr half3 a = half3( 16,  16,  32);
	constexpr half3 b = half3(256, 128,   0);
	half x = (half)popcount(msk) / 32.h;
	return {half4(mix(a, b, x)/256.h, 1.h)};
}


static inline half3 smpdefault(sampler smp, float2 uv, texture2d<half> tex, half3 def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).rgb);
}
static inline half smpdefault(sampler smp, float2 uv, texture2d<half> tex, half def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).r);
}
static inline half3 tbnx(half3 nml, half3x3 tbn) {
	return (half3)normalize(tbn * normalize(nml * 2.h - 1.h));
}
static inline material materialsmp(const mfrg f, constant materialbuf &materials) {
	constexpr sampler smp(address::repeat);
	constant modelmaterial &mmat = materials[f.mat];
	material mat;
	mat.alb = smpdefault(smp, f.tex, mmat.alb, (half3)mmat.alb_default);
	mat.nml = smpdefault(smp, f.tex, mmat.nml, (half3)mmat.nml_default);
	mat.rgh = smpdefault(smp, f.tex, mmat.rgh,  (half)mmat.rgh_default);
	mat.mtl = smpdefault(smp, f.tex, mmat.mtl,  (half)mmat.mtl_default);
	mat. ao = smpdefault(smp, f.tex, mmat. ao,  (half)mmat. ao_default);
	mat.nml = tbnx(mat.nml, {f.tgt, f.btg, f.nml});
	return mat;
}
static inline material bufmaterial(gbuf buf) {
	return {
		.alb = (half3)buf.alb.rgb,
		.nml = (half3)buf.nml.xyz,
		.rgh =  (half)buf.mat.r,
		.mtl =  (half)buf.mat.g,
		. ao =  (half)buf.mat.b,
	};
}

static inline float shadowpcf(float3 pos, light lgt, shadowmaps shds, uint lid, int n = NPCF) {
	constexpr sampler smp;
	float3 ndc = mmul3w(lgt.proj * lgt.invview, pos);
	float3 loc = float3(ndc2loc(ndc.xy), ndc.z);
	float z = loc.z - ZSHADOW;
	int shd = 0;
	for (int x = 0; x < n; ++x)
		for (int y = 0; y < n; ++y)
			shd += z > shds.sample(smp, loc.xy, lid, int2(x, y) - n/2);
	return (float)shd / (n*n);
}

static inline half3 L(half3 alb, half mtl, half ao) {
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
	float3 n = normalize((float3)mat.nml);
	float ndl = dot(n, l);
	if (ndl <= 0.f)
		return 0.f;
	float ndv = dot(n, v);
	float3 h = normalize(l + v);
	float ndh = dot(n, h);
	float vdh = dot(v, h);
	float asq = mat.rgh * mat.rgh;
	float3 fd = (float3)L(mat.alb, mat.mtl, mat.ao);
	float3 fs = 0.25f / abs(ndl * ndv);
	fs *= D(asq, ndh);
	fs *= G(asq, ndl, ndv);
	fs *= F(vdh, (float3)mix(BASE_F0, mat.alb, mat.mtl));
	return ndl * (fd + fs);
}

// xyz: normalized direction, w: attenuation
// TODO: use actual visible function pointers
typedef float4 (*attenuator)(float3 pos, light lgt, shadowmaps shds, uint lid);
static float4 attenuate_quad(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float3 dir = viewdir(lgt.view);
	float  shd = shadowpcf(pos, lgt, shds, lid, NPCF);
	return float4(dir, 1.f - shd);
}
static float4 attenuate_icos(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float3 dir = viewpos(lgt.view) - pos;
	float sqr = viewsqd(lgt.view);
	float sqd = length_squared(dir);
	return float4(normalize(dir), 1.f - sqd/sqr);
}
static float4 attenuate_cone(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float4 att = attenuate_icos(pos, lgt, shds, lid);
	if (att.a <= 0.f) // avoid acos if possible; TODO: research tradeoff for these branches
		return 0.f;
	float phi = acos(dot(att.xyz, viewdir(lgt.view)));
	if (phi >= lgt.phi) // avoid shadow smp
		return 0.f;
	att.a *= 1.f - phi/lgt.phi;
	att.a *= 1.f - shadowpcf(pos, lgt, shds, lid, NPCF);
	return att;
}

static inline bool is_qlight(light lgt) {return lgt.phi == -1.f;}
static inline bool is_ilight(light lgt) {return lgt.phi ==  0.f;}
static inline bool is_clight(light lgt) {return lgt.phi > 0.f;}
static inline float4 dispatch_attenuate(float3 pos, light lgt, shadowmaps shds, uint lid) {
	if (is_qlight(lgt)) return attenuate_quad(pos, lgt, shds, lid);
	if (is_ilight(lgt)) return attenuate_icos(pos, lgt, shds, lid);
	return attenuate_cone(pos, lgt, shds, lid);
}

static frustum make_frustum(camera cam,
							ushort2 gloc,
							ushort2 tptg,
							ushort2 tpgr,
							float mindepth,
							float maxdepth) {
	
	frustum fst;
	
	float2 ndcscale = 1.f/(float2)tpgr;
	float2 p0 = ndcscale * float2(gloc);
	float2 p1 = ndcscale * float2(gloc + tptg);
	
	float3 ndcs[6];
	ndcs[0] = float3(loc2ndc(float2(p0.x, p0.y)), 1.f); // top lt
	ndcs[1] = float3(loc2ndc(float2(p1.x, p0.y)), 1.f); // top rt
	ndcs[2] = float3(loc2ndc(float2(p0.x, p1.y)), 1.f); // bot lt
	ndcs[3] = float3(loc2ndc(float2(p1.x, p1.y)), 1.f); // bot rt
	ndcs[4] = float3(0.f, 0.f, mindepth); // z0
	ndcs[5] = float3(0.f, 0.f, maxdepth); // z1
	
	for (int i = 0; i < 6; ++i)
		fst.points[i] = mmul3w(cam.invproj, ndcs[i], 1.f);
	
	fst.planes[0] = float4(normalize(cross(fst.points[2], fst.points[0])), 0.f);
	fst.planes[1] = float4(normalize(cross(fst.points[1], fst.points[3])), 0.f);
	fst.planes[2] = float4(normalize(cross(fst.points[0], fst.points[1])), 0.f);
	fst.planes[3] = float4(normalize(cross(fst.points[3], fst.points[2])), 0.f);
	fst.planes[4] = float4(0.f, 0.f, -1.f, -fst.points[4].z);
	fst.planes[5] = float4(0.f, 0.f, +1.f, +fst.points[5].z);
	
	return fst;
	
}

static inline bool inplane_sphere(float4 plane, float3 pos, float rad = 0.f) {
	return -rad > dot(plane.xyz, pos) - plane.w;
}
static inline bool inplane_cone(float4 plane, float3 pos, float3 dir, float rad, float phi) {
	float3 m = cross(cross(plane.xyz, dir), dir);
	float3 q = pos + rad * (dir - m * tan(phi)); // obv TODO: optimize
	return inplane_sphere(plane, pos) && inplane_sphere(plane, q);
}
static inline bool visible_sphere(frustum fst, float3 pos, float rad) {
	bool vis = true;
	for (int i = 0; i < 6; ++i)
		vis &= !inplane_sphere(fst.planes[i], pos, rad);
	return vis;
}
static inline bool visible_cone(frustum fst, float3 pos, float3 dir, float rad, float phi) {
	bool vis = true;
	for (int i = 0; i < 6; ++i)
		vis &= !inplane_cone(fst.planes[i], pos, dir, rad, phi);
	return vis;
}
static inline bool visible(light lgt, frustum fst, camera cam) {
	if (is_qlight(lgt))
		return true;
	float4x4 view = cam.invview * lgt.view;
	float3 pos = viewpos(view);
	float3 dir = viewdir(view);
	float rad = viewlen(lgt.view);
	if (is_ilight(lgt))
		return visible_sphere(fst, pos, rad);
	else
		return visible_cone(fst, pos, -dir, rad, lgt.phi);
}

template <class T>
static inline void cullxp(imageblock<T, imageblock_layout_implicit> blk,
						  constant scene &scn,
						  constant light *lgts,
						  threadgroup tile &tile,
						  ushort2 tloc,
						  ushort2 gloc,
						  ushort2 tptg,
						  ushort2 gdim,
						  uint tid,
						  uint qid) {
	
	float depth = blk.read(tloc).depth;
	
	if (tid == 0) {
		atomic_store_explicit(&tile.msk, 0, memory_order_relaxed);
		tile.mindepth = INFINITY;
		tile.maxdepth = 0.0;
	}
	threadgroup_barrier(mem_flags::mem_threadgroup);
	
	float mindepth = depth;
	mindepth = min(mindepth, quad_shuffle_xor(mindepth, 2));
	mindepth = min(mindepth, quad_shuffle_xor(mindepth, 1));
	float maxdepth = depth;
	maxdepth = max(maxdepth, quad_shuffle_xor(maxdepth, 2));
	maxdepth = max(maxdepth, quad_shuffle_xor(maxdepth, 1));
	if (qid == 0) {
		atomic_fetch_min_explicit((threadgroup atomic_uint *)&tile.mindepth, as_type<uint>(mindepth), memory_order_relaxed);
		atomic_fetch_max_explicit((threadgroup atomic_uint *)&tile.maxdepth, as_type<uint>(maxdepth), memory_order_relaxed);
	}
	threadgroup_barrier(mem_flags::mem_threadgroup);
	
	frustum fst = make_frustum(scn.cam, gloc, tptg, gdim,
							   tile.mindepth,
							   tile.maxdepth);
	
	uint msk = 0;
	uint gid = tptg.x * tptg.y;
	uint n = (scn.nlgt < 32)? scn.nlgt : 32;
	for (uint lid = tid; lid < n; lid += gid)
		msk |= visible(lgts[lid], fst, scn.cam) << lid;
	atomic_fetch_or_explicit(&tile.msk, msk, memory_order_relaxed);
	
}

static half3 com_lighting(material mat,
						  float3 pos,
						  float3 eye,
						  constant light *lgts,
						  shadowmaps shds,
						  uint lid) {
#if DEBUGMASK
	return debug_mask(lgts[lid]);
#endif
	light lgt = lgts[lid];
	float4 att = dispatch_attenuate(pos, lgt, shds, lid);
	if (att.a <= 0.f)
		return 0.h;
	lgt.hue *= att.a;
	float3 dir = att.xyz;
	return (half3)saturate(lgt.hue * BDRF(mat, dir, eye));
}

static inline uint mskc(uint nlgt) {
	return !nlgt? 0u : -1u >> (32u - ((nlgt < 32u)? nlgt : 32u));
}
static inline uint mskp(threadgroup tile &tile) {
	return atomic_load_explicit(&tile.msk, memory_order_relaxed);
}
static inline cpix fwdx_lighting(const mfrg f,
								 constant materialbuf &materials,
								 constant scene &scn,
								 constant light *lgts,
								 shadowmaps shds,
								 uint msk) {
#if HEATMAP
	return heatmap(msk);
#endif
	material mat = materialsmp(f, materials);
	float3 pos = f.pos;
	float3 eye = normalize(viewpos(scn.cam.view) - pos);
	half3 rgb = 0.h;
	for (int i = 0; (i += ctz(msk >> i)) < 32; ++i)
		rgb += com_lighting(mat, pos, eye, lgts, shds, i);
	return {half4(rgb, 1.h)};
}
static inline cpix bufx_lighting(const lfrg f,
								 const gbuf buf,
								 constant scene &scn,
								 constant light *lgts,
								 shadowmaps shds,
								 uint msk) {
#if HEATMAP
	return heatmap(msk);
#endif
	if (!(msk & (1 << f.lid)))
		return {buf.color};
	material mat = bufmaterial(buf);
	float4x4 proj = scn.cam.invproj;
	float4x4 view = scn.cam.view;
	float2 loc = f.loc.xy / (float2)scn.cam.res;
	float3 ndc = float3(loc2ndc(loc), buf.depth);
	float3 pos = mmul3w(view * proj, ndc);
	float3 eye = normalize(viewpos(view) - pos);
	half3 rgb = com_lighting(mat, pos, eye, lgts, shds, f.lid);
	return {half4(buf.color.rgb + rgb, 1.h)};
}



vertex float4 vtx_shade(const device mvtx *vtcs		[[buffer(0)]],
						const device model *mdls	[[buffer(1)]],
						constant light &lgt			[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	model mdl = mdls[iid];
	float4 pos = mmul4(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj * lgt.invview, pos);
	return loc;
}

vertex mfrg vtx_main(const device mvtx *vtcs		[[buffer(0)]],
					 const device model *mdls		[[buffer(1)]],
					 constant scene &scn			[[buffer(2)]],
					 uint vid						[[vertex_id]],
					 uint iid						[[instance_id]]) {
	mvtx v = vtcs[vid];
	model mdl = mdls[iid];
	float4x4 proj = scn.cam.proj;
	float4x4 view = scn.cam.invview;
	float4x4 inv = transpose(mdl.inv);
	float4 pos = mmul4(mdl.ctm, v.pos);
	float4 loc = mmul4(proj*view, pos);
	float3 nml = normalize(mmul3(inv, (float3)v.nml, 0.f));
	float3 tgt = normalize(mmul3(inv, (float3)v.tgt.xyz, 0.f));
	float3 btg = normalize(cross(nml, tgt) * v.tgt.w);
	return {
		.loc = loc,
		.pos = pos.xyz,
		.tex = v.tex,
		.nml = (half3)nml,
		.tgt = (half3)tgt,
		.btg = (half3)btg,
		.mat = mdl.mat,
	};
}

fragment gbuf frgbufx_gbuf(const mfrg f							[[stage_in]],
						   constant materialbuf &materials		[[buffer(0)]]) {
	material mat = materialsmp(f, materials);
	return {
		.color = 0.h,
		.depth = f.loc.z,
		.alb = half4(mat.alb, 0.h),
		.nml = half4(mat.nml, 0.h),
		.mat = half4(mat.rgh, mat.mtl, mat.ao, 0.h),
	};
}

vertex lfrg vtxbufx_quad(const device pvtx *vtcs	[[buffer(0)]],
						 uint vid					[[vertex_id]],
						 uint lid					[[instance_id]]) {
	float4 loc = float4(vtcs[vid], 1.f);
	return {.loc = loc, .lid = lid};
}

vertex lfrg vtxbufx_vol(const device pvtx *vtcs 	[[buffer(0)]],
						constant scene &scn			[[buffer(2)]],
						constant light *lgts		[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint lid					[[instance_id]]) {
	float4x4 proj = scn.cam.proj;
	float4x4 view = scn.cam.invview;
	light lgt = lgts[lid];
	float4 pos = mmul4(lgt.view, vtcs[vid]);
	float4 loc = mmul4(proj*view, pos);
	return {.loc = loc, .lid = lid};
}

vertex float4 vtxfwdp_depth(const device mvtx *vtcs		[[buffer(0)]],
							const device model *mdls	[[buffer(1)]],
							constant scene &scn			[[buffer(2)]],
							uint vid					[[vertex_id]],
							uint iid					[[instance_id]]) {
	float4x4 proj = scn.cam.proj;
	float4x4 view = scn.cam.invview;
	mvtx v = vtcs[vid];
	model mdl = mdls[iid];
	float4 pos = mmul4(mdl.ctm, v.pos);
	float4 loc = mmul4(proj*view, pos);
	return loc;
}
fragment dpix frgfwdp_depth(const float4 loc [[position]]) {return {0.h, loc.z};}

kernel void knlfwdp_cull(imageblock<dpix, imageblock_layout_implicit> blk,
						 constant scene &scn			[[buffer(2)]],
						 constant light *lgts			[[buffer(3)]],
						 threadgroup tile &tile			[[threadgroup(0)]],
						 ushort2 tloc					[[thread_position_in_threadgroup]],
						 ushort2 gloc					[[thread_position_in_grid]],
						 ushort2 tptg					[[threads_per_threadgroup]],
						 ushort2 tpgr					[[threads_per_grid]],
						 uint tid						[[thread_index_in_threadgroup]],
						 uint qid						[[thread_index_in_quadgroup]]) {
	cullxp(blk, scn, lgts, tile, tloc, gloc, tptg, tpgr, tid, qid);
}
kernel void knlbufp_cull(imageblock<gbuf, imageblock_layout_implicit> blk,
						 constant scene &scn			[[buffer(2)]],
						 constant light *lgts			[[buffer(3)]],
						 threadgroup tile &tile			[[threadgroup(0)]],
						 ushort2 tloc					[[thread_position_in_threadgroup]],
						 ushort2 gloc					[[thread_position_in_grid]],
						 ushort2 tptg					[[threads_per_threadgroup]],
						 ushort2 tpgr 					[[threads_per_grid]],
						 uint tid						[[thread_index_in_threadgroup]],
						 uint qid						[[thread_index_in_quadgroup]]) {
	cullxp(blk, scn, lgts, tile, tloc, gloc, tptg, tpgr, tid, qid);
}

fragment cpix frgfwdc_light(const mfrg f						[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return fwdx_lighting(f, materials, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgfwdp_light(const mfrg f						[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							threadgroup tile &tile				[[threadgroup(0)]],
							shadowmaps shds						[[texture(0)]]) {
	return fwdx_lighting(f, materials, scn, lgts, shds, mskp(tile));
}

fragment cpix frgbufc_light(const lfrg f						[[stage_in]],
							const gbuf buf,
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return bufx_lighting(f, buf, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgbufp_light(const lfrg f						[[stage_in]],
							const gbuf buf,
							threadgroup tile &tile				[[threadgroup(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return bufx_lighting(f, buf, scn, lgts, shds, mskp(tile));
}
