#include <metal_stdlib>
using namespace metal;


#define DEBUG_MASK	0
#define DEBUG_CULL 	0

#define NMATERIAL	32
#define BASE_F0		0.04h

#define NPCF		1


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
struct spix {
	float2 mmts		[[raster_order_group(0), color(0)]];
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
struct scene {
	uint nlgt;
	camera cam;
};

struct model {
	float4x4 ctm;
	float4x4 inv;
	uint mat;
};

struct light {
	float4x4 proj;
	float3 hue;
	float3 pos;
	float3 dir;
	float rad;
	float phi;
};
using shadowmaps = texture2d_array<float>;

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
inline float3 mmulw(float4x4 mat, float4 vec) {float4 r = mat * vec; return r.xyz / r.w;}
inline float4 mmul4(float4x4 mat, float3 vec, float w = 1.f) {return mmul4(mat, float4(vec, w));}
inline float3 mmul3(float4x4 mat, float3 vec, float w = 1.f) {return mmul3(mat, float4(vec, w));}
inline float3 mmulw(float4x4 mat, float3 vec, float w = 1.f) {return mmulw(mat, float4(vec, w));}

inline float2 loc2ndc(float2 loc) {return float2((2.0f * loc.x) - 1.0f, 1.0f - (2.0f * loc.y));}
inline float2 ndc2loc(float2 ndc) {return float2((1.0f + ndc.x) * 0.5f, 0.5f * (1.0f - ndc.y));}

inline float3 viewpos(float4x4 view) {return view[3].xyz;}
inline float3 viewdlt(float4x4 view) {return view[2].xyz;}
inline float3 viewdir(float4x4 view) {return normalize(viewdlt(view));}
inline float viewsqd(float4x4 view) {return length_squared(viewdlt(view));}
inline float viewlen(float4x4 view) {return length(viewdlt(view));}

inline float3x3 orient(float3 f, float3 up = float3(0.f, 1.f, 0.f)) {
	float3 s = normalize(cross(f, up));
	float3 u = normalize(cross(s, f));
	return {s, u, -f};
}
inline float angle(float3 a, float3 b) {
	return acos(dot(a, b));
}

inline float4 scrpos(scene scn, float4 pos) {
	return mmul4(scn.cam.proj * scn.cam.invview, pos);
}
inline float3 wldpos(scene scn, float3 ndc) {
	return mmulw(scn.cam.view * scn.cam.invproj, ndc);
}
inline float3 eyedir(scene scn, float3 pos) {
	return normalize(viewpos(scn.cam.view) - pos);
}

inline bool is_qlight(light lgt) {return lgt.phi == -1.f;}
inline bool is_ilight(light lgt) {return lgt.phi ==  0.f;}
inline bool is_clight(light lgt) {return lgt.phi > 0.f;}
inline float3 lgtfwd(light lgt, float3 pos) {
	pos = orient(lgt.dir) * pos;
	pos *= lgt.rad;
	pos += lgt.pos;
	return pos;
}
inline float3 lgtbwd(light lgt, float3 pos) {
	pos -= lgt.pos;
	pos /= lgt.rad;
	pos = transpose(orient(lgt.dir)) * pos;
	return pos;
}

inline half3 debug_mask(light lgt) {
	return (half3)normalize(lgt.hue) * 0.2h;
}
inline cpix debug_cull(uint msk) {
	constexpr half3 a = half3( 16,  16,  32);
	constexpr half3 b = half3(256, 128,   0);
	half x = (half)popcount(msk) / 32.h;
	return {half4(mix(a, b, x)/256.h, 1.h)};
}

static inline half3 smpdefault(sampler smp, float2 uv, texture2d<half> tex, half3 def) {
	return saturate(is_null_texture(tex) ? def : tex.sample(smp, uv).rgb);
}
static inline half3 tbnx(half3 nml, half3x3 tbn) {
	return normalize(tbn * normalize(nml * 2.h - 1.h));
}
inline material materialsmp(const mfrg f, constant materialbuf &materials) {
	constexpr sampler smp(address::repeat);
	constant modelmaterial &mmat = materials[f.mat];
	material mat;
	mat.alb = smpdefault(smp, f.tex, mmat.alb, (half3)mmat.alb_default);
	mat.nml = smpdefault(smp, f.tex, mmat.nml, (half3)mmat.nml_default);
	mat.rgh = smpdefault(smp, f.tex, mmat.rgh, (half3)mmat.rgh_default).r;
	mat.mtl = smpdefault(smp, f.tex, mmat.mtl, (half3)mmat.mtl_default).r;
	mat. ao = smpdefault(smp, f.tex, mmat. ao, (half3)mmat. ao_default).r;
	mat.nml = tbnx(mat.nml, {f.tgt, f.btg, f.nml});
	return mat;
}
inline material bufmaterial(gbuf buf) {
	return {
		.alb = (half3)buf.alb.rgb,
		.nml = (half3)buf.nml.xyz,
		.rgh =  (half)buf.mat.r,
		.mtl =  (half)buf.mat.g,
		. ao =  (half)buf.mat.b,
	};
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

inline float4 make_plane(float3 p0, float3 p1, float3 p2) {
	float3 d0 = p0 - p2;
	float3 d1 = p1 - p2;
	float3 n = normalize(cross(d0, d1));
	return float4(n, dot(n, p2));
}
inline bool inplane(float4 plane, float3 pos, float eps = 0.f) {
	return eps >= plane.w - dot(plane.xyz, pos);
}
inline bool inplane(float4 plane, float3 p, float3 d) {
	return inplane(plane, p) || inplane(plane, p + d);
}

frustum make_frustum(camera cam,
					 float2 p0,
					 float2 p1,
					 float mindepth,
					 float maxdepth) {
	frustum fst;
	
	fst.points[0] = mmul3(cam.invproj, float3(p0.x, p0.y, 1.f), 0.f); // toplt
	fst.points[1] = mmul3(cam.invproj, float3(p1.x, p0.y, 1.f), 0.f); // toprt
	fst.points[2] = mmul3(cam.invproj, float3(p0.x, p1.y, 1.f), 0.f); // botlt
	fst.points[3] = mmul3(cam.invproj, float3(p1.x, p1.y, 1.f), 0.f); // botrt

	fst.points[4] = mmulw(cam.invproj, float3(0.f, 0.f, mindepth)); // z0
	fst.points[5] = mmulw(cam.invproj, float3(0.f, 0.f, maxdepth)); // z1
	
	fst.planes[0] = make_plane(fst.points[2], fst.points[0], 0.f); // lt
	fst.planes[1] = make_plane(fst.points[1], fst.points[3], 0.f); // rt
	fst.planes[2] = make_plane(fst.points[0], fst.points[1], 0.f); // top
	fst.planes[3] = make_plane(fst.points[3], fst.points[2], 0.f); // bot
	
	fst.planes[4] = float4(0.f, 0.f, -1.f, -fst.points[4].z); // near
	fst.planes[5] = float4(0.f, 0.f, +1.f, +fst.points[5].z); // far
	
	return fst;
}

static inline bool visible_quad(light lgt, frustum fst, camera cam) {return true;}
static inline bool visible_icos(light lgt, frustum fst, camera cam) {
	float3 p = mmul3(cam.invview, lgt.pos, 1.f);
	bool vis = true;
	for (int i = 0; i < 6; ++i)
		vis &= inplane(fst.planes[i], p, lgt.rad);
	return vis;
}
static inline bool visible_cone(light lgt, frustum fst, camera cam) {
	float3 p = mmul3(cam.invview, lgt.pos, 1.f);
	float3 d = mmul3(cam.invview, lgt.dir, 0.f);
	d = normalize(d);
	float t = tan(lgt.phi);
	bool vis = true;
	for (int i = 0; i < 6; ++i) {
		float4 plane = fst.planes[i];
		float3 m = plane.xyz;
		m = normalize(cross(d, m));
		m = normalize(cross(d, m));
		vis &= inplane(plane, p, lgt.rad * (d - t*m));
	}
	return vis;
}
static inline bool dispatch_visible(light lgt, frustum fst, camera cam) {
	if (is_qlight(lgt)) return visible_quad(lgt, fst, cam);
	if (is_ilight(lgt)) return visible_icos(lgt, fst, cam);
	return visible_cone(lgt, fst, cam);
}

template <class T>
static inline void cullxp(imageblock<T, imageblock_layout_implicit> blk,
				   constant scene &scn,
				   constant light *lgts,
				   threadgroup tile &tile,
				   ushort2 titg,
				   ushort2 tgig,
				   ushort2 tptg,
				   ushort2 tgpg,
				   uint tid) {
	
	if (tid == 0) {
		atomic_store_explicit(&tile.msk, 0, memory_order_relaxed);
		tile.mindepth = INFINITY;
		tile.maxdepth = 0.0;
	}
	threadgroup_barrier(mem_flags::mem_threadgroup);
	uint udep = as_type<uint>(blk.read(titg).depth);
	atomic_fetch_min_explicit((threadgroup atomic_uint *)&tile.mindepth, udep, memory_order_relaxed);
	atomic_fetch_max_explicit((threadgroup atomic_uint *)&tile.maxdepth, udep, memory_order_relaxed);
	threadgroup_barrier(mem_flags::mem_threadgroup);
	
	float2 gdtg = 1.f/(float2)tgpg;
	frustum fst = make_frustum(scn.cam,
							   loc2ndc(gdtg * float2(tgig)),
							   loc2ndc(gdtg * float2(tgig + 1)),
							   tile.mindepth,
							   tile.maxdepth);
	
	uint msk = 0;
	uint gid = tptg.x * tptg.y;
	uint n = (scn.nlgt < 32)? scn.nlgt : 32;
	for (uint lid = tid; lid < n; lid += gid)
		msk |= dispatch_visible(lgts[lid], fst, scn.cam) << lid;
	atomic_fetch_or_explicit(&tile.msk, msk, memory_order_relaxed);
	
}

inline float shadowcmp(shadowmaps shds, uint lid, float2 loc, float dep, int2 off = 0) {
	constexpr sampler smp(filter::linear);
	constexpr float vmin = 2e-4f;
	constexpr float pmin = 0.8f;
	constexpr float pmax = 1.5f;
	float2 mmts = shds.sample(smp, loc, lid, off).rg;
	float v = max(vmin, mmts.y - (mmts.x * mmts.x));
	float d = dep - mmts.x;
	float p = v / (v + d*d);
	return (d <= 0)? 1.f : smoothstep(pmin, pmax, p);
}
static inline float shadow(shadowmaps shds, light lgt, uint lid, float3 pos) {
	float3 ndc = mmulw(lgt.proj, lgtbwd(lgt, pos));
	float2 loc = ndc2loc(ndc.xy);
	float dep = ndc.z;
	float sum = 0.f;
	for (int x = 0; x < NPCF; ++x)
		for (int y = 0; y < NPCF; ++y)
			sum += shadowcmp(shds, lid, loc, dep, int2(x, y) - NPCF/2);
	return sum / (NPCF*NPCF);
}
static inline float shadow_quad(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return shadow(shds, lgt, lid, pos);
}
static inline float shadow_cone(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return shadow(shds, lgt, lid, pos);
}
static inline float shadow_icos(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return 0.f; // TODO: use orient?
}

// xyz: normalized direction, w: attenuation
// TODO: use actual visible function pointers
typedef float4 (*attenuator)(float3 pos, light lgt, shadowmaps shds, uint lid);
inline float4 attenuate_quad(float3 pos, light lgt, shadowmaps shds, uint lid) {
	return float4(-lgt.dir, shadow_quad(pos, lgt, shds, lid));
}
inline float4 attenuate_icos(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float3 dir = lgt.pos - pos;
	float rad = length(dir);
	float att = 1.f - rad/lgt.rad;
	if (att <= 0.f)
		return 0.f;
	dir /= rad;
	return float4(dir, att * shadow_icos(pos, lgt, shds, lid));
}
inline float4 attenuate_cone(float3 pos, light lgt, shadowmaps shds, uint lid) {
	float att = 1.f;
	float3 dir = lgt.pos - pos;
	float rad = length(dir);
	float phi = angle(-lgt.dir, dir /= rad);
	att *= max(0.f, 1.f - rad/lgt.rad);
	att *= max(0.f, 1.f - phi/lgt.phi);
	if (att <= 0.f)
		return 0.f;
	return float4(dir, att * shadow_cone(pos, lgt, shds, lid));
}
static inline float4 dispatch_attenuate(float3 pos, light lgt, shadowmaps shds, uint lid) {
	if (is_qlight(lgt)) return attenuate_quad(pos, lgt, shds, lid);
	if (is_ilight(lgt)) return attenuate_icos(pos, lgt, shds, lid);
	return attenuate_cone(pos, lgt, shds, lid);
}

static inline half3 com_lighting(material mat,
						  float3 pos,
						  float3 eye,
						  constant light *lgts,
						  shadowmaps shds,
						  uint lid) {
	light lgt = lgts[lid];
#if DEBUG_MASK
	return debug_mask(lgt);
#endif
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
inline cpix fwdx_lighting(mfrg f,
						  constant materialbuf &materials,
						  constant scene &scn,
						  constant light *lgts,
						  shadowmaps shds,
						  uint msk) {
#if DEBUG_CULL
	return debug_cull(msk);
#endif
	material mat = materialsmp(f, materials);
	float3 pos = f.pos;
	float3 eye = eyedir(scn, pos);
	half3 rgb = 0.h;
	for (int i = 0; (i += ctz(msk >> i)) < 32; ++i)
		rgb += com_lighting(mat, pos, eye, lgts, shds, i);
	return {half4(rgb, 1.h)};
}
inline cpix bufx_lighting(lfrg f,
						  const gbuf buf,
						  constant scene &scn,
						  constant light *lgts,
						  shadowmaps shds,
						  uint msk) {
#if DEBUG_CULL
	return debug_cull(msk);
#endif
	if (!(msk & (1 << f.lid)))
		return {buf.color};
	material mat = bufmaterial(buf);
	float3 pos = wldpos(scn, float3(loc2ndc(f.loc.xy/(float2)scn.cam.res), buf.depth));
	float3 eye = eyedir(scn, pos);
	half3 rgb = buf.color.rgb + com_lighting(mat, pos, eye, lgts, shds, f.lid);
	return {half4(rgb, 1.h)};
}

vertex float4 vtx_shade(const device mvtx *vtcs		[[buffer(0)]],
						const device model *mdls	[[buffer(1)]],
						constant light &lgt			[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint iid					[[instance_id]]) {
	model mdl = mdls[iid];
	float4 pos = mmul4(mdl.ctm, vtcs[vid].pos);
	float4 loc = mmul4(lgt.proj, lgtbwd(lgt, pos.xyz), pos.w);
	return loc;
}
fragment spix frg_shade(float4 loc [[position]]) {
	float z = loc.z;
	float2 mmts;
	float dx = dfdx(z);
	float dy = dfdy(z);
	mmts.x = z;
	mmts.y = z*z + 0.25*(dx*dx + dy*dy);
	return {mmts};
}

vertex mfrg vtx_main(const device mvtx *vtcs		[[buffer(0)]],
					 const device model *mdls		[[buffer(1)]],
					 constant scene &scn			[[buffer(2)]],
					 uint vid						[[vertex_id]],
					 uint iid						[[instance_id]]) {
	mvtx v = vtcs[vid];
	model mdl = mdls[iid];
	float4x4 inv = transpose(mdl.inv);
	float4 pos = mmul4(mdl.ctm, v.pos);
	float3 nml = normalize(mmul3(inv, (float3)v.nml, 0.f));
	float3 tgt = normalize(mmul3(inv, (float3)v.tgt.xyz, 0.f));
	float3 btg = normalize(cross(nml, tgt) * v.tgt.w);
	return {
		.loc = scrpos(scn, pos),
		.pos = pos.xyz,
		.tex = v.tex,
		.nml = (half3)nml,
		.tgt = (half3)tgt,
		.btg = (half3)btg,
		.mat = mdl.mat,
	};
}

fragment gbuf frgbufx_gbuf(mfrg f								[[stage_in]],
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
	return {.loc = float4(vtcs[vid], 1.f), .lid = lid};
}

vertex lfrg vtxbufx_vol(const device pvtx *vtcs 	[[buffer(0)]],
						constant scene &scn			[[buffer(2)]],
						constant light *lgts		[[buffer(3)]],
						uint vid					[[vertex_id]],
						uint lid					[[instance_id]]) {
	float3 pos = lgtfwd(lgts[lid], vtcs[vid]);
	float4 loc = scrpos(scn, float4(pos, 1.f));
	return {.loc = loc, .lid = lid};
}

vertex float4 vtxfwdp_depth(const device mvtx *vtcs		[[buffer(0)]],
							const device model *mdls	[[buffer(1)]],
							constant scene &scn			[[buffer(2)]],
							uint vid					[[vertex_id]],
							uint iid					[[instance_id]]) {
	model mdl = mdls[iid];
	float4 pos = mdl.ctm * float4(vtcs[vid].pos, 1.f);
	float4 loc = scrpos(scn, pos);
	return loc;
}
fragment dpix frgfwdp_depth(float4 loc [[position]]) {return {0.h, loc.z};}

kernel void knlfwdp_cull(imageblock<dpix, imageblock_layout_implicit> blk,
						 constant scene &scn			[[buffer(2)]],
						 constant light *lgts			[[buffer(3)]],
						 threadgroup tile &tile			[[threadgroup(0)]],
						 ushort2 tptg					[[threads_per_threadgroup]],
						 ushort2 titg					[[thread_position_in_threadgroup]],
						 ushort2 tgpg					[[threadgroups_per_grid]],
						 ushort2 tgig					[[threadgroup_position_in_grid]],
						 uint tid						[[thread_index_in_threadgroup]]) {
	cullxp(blk, scn, lgts, tile, titg, tgig, tptg, tgpg, tid);
}
kernel void knlbufp_cull(imageblock<gbuf, imageblock_layout_implicit> blk,
						 constant scene &scn			[[buffer(2)]],
						 constant light *lgts			[[buffer(3)]],
						 threadgroup tile &tile			[[threadgroup(0)]],
						 ushort2 tloc					[[thread_position_in_threadgroup]],
						 ushort2 gloc					[[thread_position_in_grid]],
						 ushort2 tptg					[[threads_per_threadgroup]],
						 ushort2 tpgr 					[[threads_per_grid]],
						 uint tid						[[thread_index_in_threadgroup]]) {
	cullxp(blk, scn, lgts, tile, tloc, gloc, tptg, tpgr, tid);
}

fragment cpix frgfwdc_light(mfrg f								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return fwdx_lighting(f, materials, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgfwdp_light(mfrg f								[[stage_in]],
							constant materialbuf &materials		[[buffer(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							threadgroup tile &tile				[[threadgroup(0)]],
							shadowmaps shds						[[texture(0)]]) {
	return fwdx_lighting(f, materials, scn, lgts, shds, mskp(tile));
}

fragment cpix frgbufc_light(lfrg f								[[stage_in]],
							const gbuf buf,
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return bufx_lighting(f, buf, scn, lgts, shds, mskc(scn.nlgt));
}
fragment cpix frgbufp_light(lfrg f								[[stage_in]],
							const gbuf buf,
							threadgroup tile &tile				[[threadgroup(0)]],
							constant scene &scn					[[buffer(2)]],
							constant light *lgts				[[buffer(3)]],
							shadowmaps shds						[[texture(0)]]) {
	return bufx_lighting(f, buf, scn, lgts, shds, mskp(tile));
}
