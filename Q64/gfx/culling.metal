#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "culling.h"


typedef struct {float3 n; float d = 0.f;} plane;
typedef plane frustum[6];

void make_frustum(frustum fst,
				  xcamera cam,
				  ushort2 scr0,
				  ushort2 scr1,
				  float mindepth,
				  float maxdepth) {
	float3 pts[6];
	pts[0] = eyepos(cam, float2(scr0.x, scr0.y), 1.f);
	pts[1] = eyepos(cam, float2(scr1.x, scr0.y), 1.f);
	pts[2] = eyepos(cam, float2(scr0.x, scr1.y), 1.f);
	pts[3] = eyepos(cam, float2(scr1.x, scr1.y), 1.f);
	pts[4] = eyepos(cam, 0.f, mindepth);
	pts[5] = eyepos(cam, 0.f, maxdepth);
	fst[0] = {.n = normalize(cross(pts[2], pts[0]))};
	fst[1] = {.n = normalize(cross(pts[1], pts[3]))};
	fst[2] = {.n = normalize(cross(pts[0], pts[1]))};
	fst[3] = {.n = normalize(cross(pts[3], pts[2]))};
	fst[4] = {.n = {0.f, 0.f, -1.f}, .d = -pts[4].z};
	fst[5] = {.n = {0.f, 0.f, +1.f}, .d = +pts[5].z};
}

inline bool inplane(plane p, float3 pos, float eps = 0.f) {
	return dot(pos, p.n) >= p.d - eps;
}
inline bool inplane(plane p, float3 pos, float3 dir) {
	return inplane(p, pos) || inplane(p, pos + dir);
}

typedef bool (*viscmp)(xlight lgt, frustum fst, xcamera cam);
inline bool qvis(xlight lgt, frustum fst, xcamera cam) {return true;}
inline bool ivis(xlight lgt, frustum fst, xcamera cam) {
	float3 pos = mmul3(cam.invview, lgt.pos, 1.f);
	bool vis = true;
	for (int i = 0; i < 6; ++i)
		vis &= inplane(fst[i], pos, lgt.rad);
	return vis;
}
inline bool cvis(xlight lgt, frustum fst, xcamera cam) {
	float3 pos = mmul3(cam.invview, lgt.pos, 1.f);
	float3 dir = mmul3(cam.invview, lgt.dir, 0.f);
	dir = normalize(dir);
	float c = lgt.rad * cos(lgt.phi);
	float s = lgt.rad * sin(lgt.phi);
	bool vis = true;
	for (int i = 0; i < 6; ++i) {
		float3 nml = fst[i].n;
		nml = cross(nml, dir);
		nml = cross(nml, dir);
		nml = normalize(nml);
		vis &= inplane(fst[i], pos, c*dir - s*nml);
	}
	return vis;
}

inline bool dispatch_viscmp(xlight lgt, frustum fst, xcamera cam) {
	constexpr viscmp cmps[3] = {qvis, ivis, cvis};
	return cmps[light_type(lgt)](lgt, fst, cam);
}

kernel void knl_cull(imageblock<dpix, imageblock_layout_implicit> blk,
					 constant xscene &scn		[[buffer(2)]],
					 constant xlight *lgts		[[buffer(3)]],
					 threadgroup tile &tile		[[threadgroup(0)]],
					 ushort tid					[[thread_index_in_threadgroup]],
					 ushort2 tptg				[[threads_per_threadgroup]],
					 ushort2 titg				[[thread_position_in_threadgroup]],
					 ushort2 tgpg				[[threadgroups_per_grid]],
					 ushort2 tgig				[[threadgroup_position_in_grid]]) {

	if (tid == 0) {
		atomic_store_explicit(&tile.msk, 0u, memory_order_relaxed);
		tile.mindepth = FLT_MAX;
		tile.maxdepth = 0.f;
	}
	threadgroup_barrier(mem_flags::mem_threadgroup);

	uint z = as_type<uint>(blk.read(titg).depth);
	atomic_fetch_min_explicit((threadgroup atomic_uint *)&tile.mindepth, z, memory_order_relaxed);
	atomic_fetch_max_explicit((threadgroup atomic_uint *)&tile.maxdepth, z, memory_order_relaxed);
	threadgroup_barrier(mem_flags::mem_threadgroup);

	frustum fst;
	make_frustum(fst, scn.cam,
				 tptg * tgig,
				 tptg * (tgig + 1),
				 tile.mindepth,
				 tile.maxdepth);

	uint msk = 0u;
	for (uint lid = tid; lid < scn.nlgt; lid += tptg.x*tptg.y)
		msk |= dispatch_viscmp(lgts[lid], fst, scn.cam) << lid;
	atomic_fetch_or_explicit(&tile.msk, msk, memory_order_relaxed);
	
}
