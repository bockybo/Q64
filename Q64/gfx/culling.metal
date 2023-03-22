#import <metal_stdlib>
using namespace metal;

#import "util.h"
#import "culling.h"


struct frustum {
	float4 planes[6];
	float3 points[8]; // TODO: use for aabb?
};

frustum make_frustum(xcamera cam,
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
inline bool visible_quad(xlight lgt, frustum fst, xcamera cam) {return true;}
inline bool visible_icos(xlight lgt, frustum fst, xcamera cam) {
	float3 p = mmul3(cam.invview, lgt.pos, 1.f);
	bool vis = true;
	for (int i = 0; i < 6; ++i)
		vis &= inplane(fst.planes[i], p, lgt.rad);
	return vis;
}
inline bool visible_cone(xlight lgt, frustum fst, xcamera cam) {
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
inline bool dispatch_visible(xlight lgt, frustum fst, xcamera cam) {
	if (is_qlight(lgt)) return visible_quad(lgt, fst, cam);
	if (is_ilight(lgt)) return visible_icos(lgt, fst, cam);
	return visible_cone(lgt, fst, cam);
}

kernel void knl_cull(imageblock<dpix, imageblock_layout_implicit> blk,
					 constant xscene &scn		[[buffer(2)]],
					 constant xlight *lgts		[[buffer(3)]],
					 threadgroup tile &tile		[[threadgroup(0)]],
					 ushort2 tptg				[[threads_per_threadgroup]],
					 ushort2 titg				[[thread_position_in_threadgroup]],
					 ushort2 tgpg				[[threadgroups_per_grid]],
					 ushort2 tgig				[[threadgroup_position_in_grid]],
					 uint tid					[[thread_index_in_threadgroup]]) {
	
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

