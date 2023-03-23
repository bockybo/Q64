
#define MAX_NMATERIAL		64
#define MAX_NMODEL			1024
#define MAX_NLIGHT			32
#define MAX_NSHADE			32

#define DEBUG_MASK			0
#define DEBUG_CULL 			0

#define BASE_F0				0.04f

#define SHD_NPCF			3
#define SHD_VMIN			1e-7f
#define SHD_PMIN			0.2f

#define FD					FD_lambert
#define FS					FS_schlick
#define NDF					NDF_ggx
#define GSF					GSF_smith
