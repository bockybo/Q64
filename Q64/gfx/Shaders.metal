#include <metal_stdlib>
using namespace metal;


typedef texture2d<float, access::sample> texmap2;
typedef depth2d  <float, access::sample> depmap2;

typedef struct {
	packed_float3 pos;
	packed_float3 nml;
	packed_float2 tex;
} vtx;
typedef struct {
	float4 camloc [[position]];
	float4 lgtloc;
	float2 texloc;
	float3 nml;
	float3 pos;
	float imf;
} frg;
typedef struct {
	half4 alb [[color(0)]];
	half4 nml [[color(1)]];
	half4 pos [[color(2)]];
} gbuf;

typedef struct {
	uint imf;
	float4x4 ctm;
} mvtx;
typedef struct {
	float3 ambi;
	float3 diff;
	float3 spec;
	float shine;
} mfrg;

typedef struct {
	float3 hue;
	float3 dir;
	float rad;
} lfrg;

typedef struct {
	float4 loc [[position]];
	uint iid [[flat]];
} pix;


static inline float3 color(float2 loc, texmap2 texmap) {
	constexpr sampler smp;
	if (is_null_texture(texmap))
		return 1;
	return texmap.sample(smp, loc).rgb;
}
static inline float shade(float4 loc, depmap2 shdmap) {
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
static inline lfrg attenuate(lfrg lgt, float3 pos) {
	float sqd = length_squared(lgt.dir -= pos);
	float sqr = lgt.rad * lgt.rad;
	lgt.hue *= 1 - sqd/sqr;
	lgt.dir = normalize(lgt.dir);
	return lgt;
}
static inline float3 light(lfrg lgt, mfrg mat, float3 pos, float3 nml, float3 eye) {
	float kdiff = saturate(dot(nml, lgt.dir));
	float kspec = saturate(dot(normalize(pos - eye), reflect(lgt.dir, nml)));
	float3 diff = mat.diff * kdiff;
	float3 spec = mat.spec * pow(kspec, mat.shine);
	return diff + spec;
}


vertex float4 vtx_shdw(constant vtx *vtcs			[[buffer(0)]],
					   constant mvtx *mdls			[[buffer(1)]],
					   constant float4x4 &lgtctm	[[buffer(2)]],
					   uint vid						[[vertex_id]],
					   uint iid						[[instance_id]]) {
	float3 v = vtcs[vid].pos;
	mvtx mdl = mdls[iid];
	return lgtctm * mdl.ctm * float4(v, 1);
}

vertex frg vtx_main(constant vtx *vtcs				[[buffer(0)]],
					constant mvtx *mdls				[[buffer(1)]],
					constant float4x4 &lgtctm		[[buffer(2)]],
					constant float4x4 &camctm		[[buffer(3)]],
					uint vid						[[vertex_id]],
					uint iid						[[instance_id]]) {
	vtx v = vtcs[vid];
	mvtx mdl = mdls[iid];
	float4 pos = mdl.ctm * float4(v.pos, 1);
	float4 nml = mdl.ctm * float4(v.nml, 0);
	return {
		.camloc = camctm * pos,
		.lgtloc = lgtctm * pos,
		.texloc = v.tex,
		.nml = normalize(nml.xyz),
		.pos = pos.xyz,
		.imf = (float)mdl.imf,
	};
}
fragment gbuf frg_main(frg f						[[stage_in]],
					   texmap2 texmap				[[texture(0)]],
					   depmap2 shdmap				[[texture(1)]]) {
	float3 alb = color(f.texloc, texmap);
	float  shd = shade(f.lgtloc, shdmap);
	return {
		.alb = half4(half3(alb), 0),
		.nml = half4(half3(f.nml), shd),
		.pos = half4(half3(f.pos), f.imf),
	};
}


vertex pix vtx_quad(uint vid [[vertex_id]]) {
	constexpr float2 vtcs[] = {
		float2(-1,  1), float2( 1, -1), float2(-1, -1),
		float2(-1,  1), float2( 1,  1), float2( 1, -1)};
	float2 v = vtcs[vid];
	float3 pos = float3(v, 0);
	float4 loc = float4(pos, 1);
	return {.loc = loc, .iid = 0};
}

vertex pix vtx_lpos(constant packed_float3 *vtcs		[[buffer(0)]],
					constant lfrg *lgts					[[buffer(2)]],
					constant float4x4 &camctm			[[buffer(3)]],
					uint vid							[[vertex_id]],
					uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	lfrg lgt = lgts[iid];
	float3 pos = lgt.dir + lgt.rad * v;
	float4 loc = camctm * float4(pos, 1);
	return {.loc = loc, .iid = iid};
}
vertex float4 vtx_mask(constant packed_float3 *vtcs		[[buffer(0)]],
					   constant lfrg *lgts				[[buffer(2)]],
					   constant float4x4 &camctm		[[buffer(3)]],
					   uint vid							[[vertex_id]],
					   uint iid							[[instance_id]]) {
	float3 v = vtcs[vid];
	lfrg lgt = lgts[iid];
	float3 pos = lgt.dir + lgt.rad * v;
	float4 loc = camctm * float4(pos, 1);
	return loc;
}

fragment half4 frg_light(pix p					[[stage_in]],
						 constant mfrg *mats	[[buffer(1)]],
						 constant lfrg *lgts	[[buffer(2)]],
						 constant float3 &eye	[[buffer(3)]],
						 texmap2 albmap			[[texture(0)]],
						 texmap2 nmlmap			[[texture(1)]],
						 texmap2 posmap			[[texture(2)]]) {
	
	uint2 uv = (uint2)p.loc.xy ;
	float4 rd_alb = albmap.read(uv);
	float4 rd_nml = nmlmap.read(uv);
	float4 rd_pos = posmap.read(uv);
	
	float3 alb = rd_alb.rgb; // TODO: USE W :)
	float3 nml = rd_nml.xyz; float shd = rd_nml.w;
	float3 pos = rd_pos.xyz; float imf = rd_pos.a;
	
	mfrg mat = mats[(uint)imf];
	lfrg lgt = lgts[p.iid];
	
	if (lgt.rad)
		lgt = attenuate(lgt, pos);
	
	float3 amp = mat.ambi;
	float lit = 1 - shd;
	if (lit)
		amp += lit * light(lgt, mat, pos, nml, eye);
	
	float3 rgb = alb * amp * lgt.hue;
	return half4(half3(rgb), 1);
	
}
