#ifndef _PIM_H_
#define _PIM_H_


/* For PIM memory management */
#define __PIM_MALLOC__ /* If this define is disabled, pim_malloc is changed to standard malloc function */
#define __FPGA__ /* If this define is enabled, PIM driver MUST BE loaded into the kernel */
// #define __PIM_MEM_KER__ /* Enable this define when OS buddy manages PIM memory */

/* For DMA */
// #define INTR_ENABLE /* Enable interrupt. If this define is disabled, polling mode */
// #define PERF_TIME /* For time measurement */

/* For debugging */
// #define DEBUG_PL_DMA /* Xilinx CDMA debugging */
// #define DEBUG_PIM_MEM /* PIM MemPool debugging */
#define DEBUG_PIM_MATH /* PIM Math library debugging */

#define BILLION 1000000000L


/* DO NOT EDIT parameter without modification of Vivado Address Editor */
#ifdef __aarch64__
    #define HIGH_ADDR   0x00000004 /* PL DDR address is 0x40000_0000 ~ in ARM platform */
#elif defined __x86_64__
    #define HIGH_ADDR   0x00000000 /* PL DDR address is always 32 bits in x86 platform*/
#endif

typedef struct
{
	const void *srcA_ptr;
	const void *srcB_ptr;
	const void *src2_ptr;
	const void *srcbias_ptr;
	void *dstC_ptr;

	uint64_t srcA_va;
	uint64_t srcB_va;
	uint64_t bias_va;
	uint64_t dstC_va;

	uint32_t srcA_size;
	uint32_t srcB_size;
	uint32_t src2_size;
	uint32_t dstC_size;

	uint32_t p_size;
	uint32_t q_size;
	uint32_t r_size;

	uint32_t desc_idx;
	uint32_t desc_last;
	uint32_t fused_op;
	uint32_t length;

	uint64_t dma_tx;
    void *dma_tx_ptr;
    uint64_t desc_base;
    uint64_t dram_base;
    void *desc_host;
    uint64_t va;
    uint64_t pa;
} __attribute__ ((packed)) pim_args;
// } pim_args;


typedef uint16_t Bfloat16;


#define PL_DMA_DRV "/dev/pl_dma"
#define PS_DMA_DRV "/dev/ps_dma"
#define X86_DMA_DRV "/dev/x86_dma"

#define PL_DRV_NAME "pl_dma"
#define PS_DRV_NAME "ps_dma"
#define HOST_DRV_NAME "x86_dma"
#define PIM_CONF_DRV_NAME "pim_conf_reg"

#define PL_DMA_REG_NAME "reg-region"
#define PL_DMA_DESC_NAME "desc-region"
#define CONF_BRAM_NAME "conf-bram-region"
#define CONF_REG_NAME "conf-reg-region"

#define PIM_MEM "pim-mem-region"
#define DRIVER_NAME "pim_mmap_dev"

enum {
	/* MUST skip the 0x0 ~ 0x2 */
	/* 3*/ DMA_START = 0x3,
	DESC_MEM_INFO,
	VA_TO_PA,
	MEMCPY_PL2PL,
	MEMCPY_PL2PS,
	MEMCPY_PS2PL,
	/* For operator fusion opcode */
	FUSED_ELEW_ADD,
	FUSED_ELEW_SUB
};


/* 
 * For x86 host dma ioctl 
 */
#define HOST2HOST             	0
#define HOST2FPGA             	1
#define FPGA2HOST             	2
#define H2H_ZCPY              	3

#ifdef __cplusplus
extern "C"
{
#endif

#ifdef DEBUG_PIM_MEM
#define PIM_MEM_LOG(fmt, ...) printf(fmt, ##__VA_ARGS__);
#else
#define PIM_MEM_LOG(fmt, ...)
#endif

#ifdef DEBUG_PIM_MATH
#define PIM_MATH_LOG(fmt, ...) printf(fmt, ##__VA_ARGS__);
#else
#define PIM_MATH_LOG(fmt, ...)
#endif

/* 
 * External functions for PIM operation
 */
extern uint64_t VA2PA(uint64_t va);
extern void *pim_malloc(size_t size);
extern void pim_free(void *addr);
extern int init_pim_drv(void);
extern int matmul(pim_args *pim_args);
extern int matmul_tiled(pim_args *pim_args);
extern int gemm(pim_args *pim_args);
extern int matmul_fusion(pim_args *pim_args);
extern int elewise_add(pim_args *pim_args);
extern int elewise_sub(pim_args *pim_args);
extern int elewise_mul(pim_args *pim_args);
extern int bias_add(pim_args *pim_args);
extern int bias_sub(pim_args *pim_args);
extern int bias_mul(pim_args *pim_args);

#ifdef __cplusplus
}  /* Assume C declarations for C++ */
#endif /* __cplusplus */
#endif
