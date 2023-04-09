#import <metal_stdlib>
using namespace metal;

#import "config.h"
#import "util.h"
#import "culling.h"


// repr NCLUSTER-independent translation of cluster index<->depth
struct clusterscheme {
	float (*clus2z)(xcamera, float i);
	float (*z2clus)(xcamera, float z);
};
float clus2z_lin(xcamera cam, float i) {return mix(cam.z0, cam.z1, i);}
float z2clus_lin(xcamera cam, float z) {return lin(cam.z0, cam.z1, z);}
float clus2z_log(xcamera cam, float i) {return mix(cam.z0, cam.z1, exp2m1(i));}
float z2clus_log(xcamera cam, float z) {return log2p1(lin(cam.z0, cam.z1, z));}
float clus2z_pow(xcamera cam, float i) {return cam.z0 * pow(cam.z1/cam.z0, i);}
float z2clus_pow(xcamera cam, float z) {return log(z/cam.z0) / log(cam.z1/cam.z0);}
constant clusterscheme scheme_linear		= {clus2z_lin, z2clus_lin};
constant clusterscheme scheme_logarithmic	= {clus2z_log, z2clus_log};
constant clusterscheme scheme_zpower		= {clus2z_pow, z2clus_pow};
inline float clus2z(xcamera cam, int i) {return CLUSTERSCHEME.clus2z(cam, i / (float)NCLUSTER);}
inline int z2clus(xcamera cam, float z) {return CLUSTERSCHEME.z2clus(cam, z) * (float)NCLUSTER;}


struct bbox {
	float3 pmin = -INFINITY;
	float3 pmax = +INFINITY;
	bbox() = default;
	bbox(float3 p, float3 q): pmin(min(p, q)), pmax(max(p, q)) {}
	float3 ctr() {return 0.5f * (pmin + pmax);}
	float3 ext() {return 0.5f * (pmax - pmin);}
	float minsqd(float3 p) {
		return (length_squared(max(0.f, pmin - p)) +
				length_squared(max(0.f, p - pmax)));
	}
};
struct chunk {
	bbox box;
	float hyp;
	chunk(float2 p0,
		  float2 p1,
		  float z0,
		  float z1) {
		box = bbox(z0 * float3(p0, -1.f),
				   z1 * float3(p1, -1.f));
		hyp = length(box.pmax - box.ctr());
	}
	bool visible(float3 p, float r = 0.f) {
		return r*r >= box.minsqd(p);
	}
	bool visible(float3 p, float3 v, float r, float c, float s) {
		float3 d = box.ctr() - p;
		float sqd = length_squared(d);
		float len = dot(d, v);
		float minlen = c*sqrt(sqd - len*len) - s*len;
		return visible(p, r) && !(minlen >  hyp
								  || len >  hyp + r
								  || len < -hyp);
	}
};


typedef bool (*viscmp)(chunk ch, float4x4 inv, xlight lgt);
inline bool qvis(chunk ch, float4x4 inv, xlight lgt) {return true;}
inline bool ivis(chunk ch, float4x4 inv, xlight lgt) {
	float3 p = mmul3(inv, lgt.pos, 1.f);
	float  r = lgt.rad;
	return ch.visible(p, r);
}
inline bool cvis(chunk ch, float4x4 inv, xlight lgt) {
	float3 p = mmul3(inv, lgt.pos, 1.f);
	float3 v = mmul3(inv, lgt.dir, 0.f);
	float r = lgt.rad;
	float c = cos(lgt.phi);
	float s = sin(lgt.phi);
	return ch.visible(p, normalize(v), r, c, s);
}
inline bool dispatch_visible(chunk ch, float4x4 inv, xlight lgt) {
	constexpr viscmp cmps[3] = {qvis, ivis, cvis};
	return cmps[light_type(lgt)](ch, inv, lgt);
}
inline uint com_culling(chunk ch,
						constant xlight *lgts,
						constant xscene &scn,
						uint start,
						uint stride) {
	uint bin = 0u;
	for (uint i = start; i < scn.nlgt; i += stride)
		bin |= dispatch_visible(ch, scn.cam.invview, lgts[i]) << i;
	return bin;
}


#define ATOMIC(op, ...) atomic_##op##_explicit(__VA_ARGS__, memory_order_relaxed)

uint ldbin(uint nlgt) {
	return -1u >> -min(0u, nlgt - MAX_NLIGHT);
}
uint ldbin(threadgroup visbin &bin) {
	return ATOMIC(load, &bin);
}
uint ldbin(threadgroup visbin *bins, xcamera cam, float z) {
	return ATOMIC(load, &bins[z2clus(cam, unproj00z(cam, z))]);
}

struct zbound {
	atomic_uint zmin;
	atomic_uint zmax;
};
kernel void knl_cull(imageblock<dpix, imageblock_layout_implicit> blk,
					 constant xscene &scn			[[buffer(2)]],
					 constant xlight *lgts			[[buffer(3)]],
					 threadgroup visbin *bins		[[threadgroup(0)]],
					 threadgroup zbound &bnds		[[threadgroup(1)]],
					 uint tix						[[thread_index_in_threadgroup]],
					 uint2 tid						[[thread_position_in_threadgroup]],
					 uint2 gid						[[threadgroup_position_in_grid]],
					 uint2 dim						[[threads_per_threadgroup]]) {
	if (tix == 0) {
		ATOMIC(store, &bins[0], 0u);
		ATOMIC(store, &bnds.zmin, as_type<uint>(FLT_MAX));
		ATOMIC(store, &bnds.zmax, as_type<uint>(0.f));
	}
	threadgroup_barrier(mem_flags::mem_threadgroup);
	float z = blk.read((ushort2)tid).depth;
	ATOMIC(fetch_min, &bnds.zmin, as_type<uint>(z));
	ATOMIC(fetch_max, &bnds.zmax, as_type<uint>(z));
	threadgroup_barrier(mem_flags::mem_threadgroup);
	chunk ch(unprojxy1(scn.cam, float2(dim * gid)),
			 unprojxy1(scn.cam, float2(dim * (gid + 1u))),
			 unproj00z(scn.cam, as_type<float>(ATOMIC(load, &bnds.zmin))),
			 unproj00z(scn.cam, as_type<float>(ATOMIC(load, &bnds.zmax))));
	ATOMIC(fetch_or, &bins[0], com_culling(ch, lgts, scn, tix, dim.x*dim.y));
}

kernel void knl_clus(constant xscene &scn		[[buffer(2)]],
					 constant xlight *lgts		[[buffer(3)]],
					 threadgroup visbin *bins	[[threadgroup(0)]],
					 uint tix					[[thread_index_in_threadgroup]],
					 uint2 gid					[[threadgroup_position_in_grid]],
					 uint2 dim					[[threads_per_threadgroup]]) {
	if (tix < NCLUSTER) {
		chunk ch(unprojxy1(scn.cam, float2(dim * gid)),
				 unprojxy1(scn.cam, float2(dim * (gid + 1u))),
				 clus2z(scn.cam, tix),
				 clus2z(scn.cam, tix + 1));
		uint bin = 0u;
		for (uint i = 0; i < scn.nlgt; ++i)
			bin |= dispatch_visible(ch, scn.cam.invview, lgts[i]) << i;
		ATOMIC(store, &bins[tix], bin);
	}
}
