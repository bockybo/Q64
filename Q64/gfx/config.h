#ifndef shaderconfig_h
#define shaderconfig_h


#define DEBUG_MASK	0
#define DEBUG_CULL 	0

#define NMATERIAL	32
#define BASE_F0		0.04f

#define FD			FD_lambert
#define FS			FS_schlick
#define NDF			NDF_trowreitz
#define GSF			GSF_ggxwalter

#define SHD_NPCF	4
#define SHD_VMIN	1e-7f
#define SHD_PMIN	0.2f


#endif
