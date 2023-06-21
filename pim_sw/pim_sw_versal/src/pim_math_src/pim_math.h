#ifndef _PIM_MATH_LIB_
#define _PIM_MATH_LIB_

#include <sys/mman.h>
#include <stddef.h>
#include <stdio.h>
#include <assert.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <stdbool.h>
#include "../drv_src/pim_mem_lib_user.h"
#include "../../include/pim.h"

#define OPCODE_MAT_MUL 0x851F
#define OPCODE_MAT_MUL_DECOUPLED_8x4  0x1051F
#define OPCODE_ELE_ADD 0x42F
#define OPCODE_GEMM_ADD 0x1042F

#define OPCODE_ELE_SUB 0x44F
#define OPCODE_ELE_MUL 0x48F
#define OPCODE_PROF 0x100000

#define OPCODE_LUT    0x1080F

#define BURST_SIZE 32 /* Byte size */
#define TYPE_SIZE sizeof(short) /* Pre-defined bfloat16 type */
#define REG_SIZE (BURST_SIZE / TYPE_SIZE) /* vecA and vACC register size */
#define vecA_SIZE 32
#define vACC_SIZE 32
#define NUM_BANKS 16
#define PIM_WIDTH (REG_SIZE * NUM_BANKS * TYPE_SIZE)
#define LUT_WIDTH (64 * 1024 * TYPE_SIZE)

#define RD_A_ATTR 0x2
#define RD_B_ATTR 0x4
#define WR_C_ATTR 0x9

/* For Descriptor */
#define CDMA_NEXT_DE_L       0x00
#define CDMA_NEXT_DE_H       0x04
#define CDMA_DESC_SA_L       0x08
#define CDMA_DESC_SA_H       0x0C
#define CDMA_DESC_DA_L       0x10
#define CDMA_DESC_DA_H       0x14
#define CDMA_DESC_LEN        0x18
#define CDMA_DESC_STATUS     0x1C
#define CDMA_DESC_INFO       0x24 /* Use reserved bit for PIM opcode */

/* AXI CDMA Register Address Map */
#define CDMA_REG_CR          0x00
#define CDMA_REG_SR          0x04
#define CDMA_CURDESC_PNTR_L  0x08
#define CDMA_CURDESC_PNTR_H  0x0C
#define CDMA_TAILDESC_PNTR_L 0x10
#define CDMA_TAILDESC_PNTR_H 0x14
#define CDMA_REG_SA_L        0x18
#define CDMA_REG_SA_H        0x1C
#define CDMA_REG_DA_L        0x20
#define CDMA_REG_DA_H        0x24
#define CDMA_REG_BYTETRANS   0x28

#define BRAM_DUMMY 0xd0000000
#define LUT_READ_INPUT 0x00008000
//#define CONF_OFFSET_HPC_CLR 0x5000

extern uint64_t desc_base;
extern uint64_t dram_base;
extern int pim_exec(pim_args *pim_args);
extern int indirect_code_load(pim_args *pim_args);
extern int pim_exec_indirect(pim_args *pim_args);

typedef struct
{
	/* CDMA_NEXT_DE_L   */ uint32_t next_l;
	/* CDMA_NEXT_DE_H   */ uint32_t next_h;
	/* CDMA_DESC_SA_L   */ uint32_t src_l;
	/* CDMA_DESC_SA_H   */ uint32_t src_h;
	/* CDMA_DESC_DA_L   */ uint32_t dst_l;
	/* CDMA_DESC_DA_H   */ uint32_t dst_h;
	/* CDMA_DESC_LEN    */ uint32_t len;
	/* CDMA_DESC_STATUS */ uint32_t status;
} __attribute__((aligned(64))) pim_isa_t;
// } pim_isa_t;
extern pim_isa_t *pim_isa;

static inline char *decode_opcode(int opcode) {
	int low_acc = (0<<28) || (0<<24)| RD_B_ATTR | (OPCODE_LUT<<0x4);
	int high_acc = (4<<28) || (4<<24)| RD_B_ATTR | (OPCODE_LUT<<0x4);
	switch(opcode)
	{
		case 0: return "INIT";
		case (RD_A_ATTR | OPCODE_MAT_MUL << 0x4): return "MAT_MUL_SILENT_RD_A";
		case (RD_B_ATTR | OPCODE_MAT_MUL << 0x4): return "MAT_MUL_SILENT_RD_B";
		case (WR_C_ATTR | OPCODE_MAT_MUL << 0x4): return "MAT_MUL_SILENT_WR_C";
		case (RD_A_ATTR | OPCODE_MAT_MUL_DECOUPLED_8x4 << 0x4): return "MAT_MUL_DECOUPLED_RD_BANK_PRIVATE";
		case (RD_B_ATTR | OPCODE_MAT_MUL_DECOUPLED_8x4 << 0x4): return "MAT_MUL_DECOUPLED_RD_BANK_SHARED";
		case (WR_C_ATTR | OPCODE_MAT_MUL_DECOUPLED_8x4 << 0x4): return "MAT_MUL_DECOUPLED_WR_C";
		case (RD_A_ATTR | OPCODE_ELE_ADD<<0x4): return "ELE_ADD_RD_A";
		case (RD_B_ATTR | OPCODE_ELE_ADD<<0x4): return "ELE_ADD_RD_B";
		case (WR_C_ATTR | OPCODE_ELE_ADD<<0x4): return "ELE_ADD_WR_C";
		case (RD_A_ATTR | OPCODE_ELE_SUB<<0x4): return "ELE_SUB_RD_A";
		case (RD_B_ATTR | OPCODE_ELE_SUB<<0x4): return "ELE_SUB_RD_B";
		case (WR_C_ATTR | OPCODE_ELE_SUB<<0x4): return "ELE_SUB_WR_C";
		case (RD_A_ATTR | OPCODE_ELE_MUL<<0x4): return "ELE_MUL_RD_A";
		case (RD_B_ATTR | OPCODE_ELE_MUL<<0x4): return "ELE_MUL_RD_B";
		case (WR_C_ATTR | OPCODE_ELE_MUL<<0x4): return "ELE_MUL_WR_C";
		
		case (RD_A_ATTR | (OPCODE_LUT << 0x4)): 	 return "INDIRECT_LUT_RD_A";
		// case ((low_acc) | RD_B_ATTR | (OPCODE_LUT << 0x4)): return "INDIRECT_LUT_COMPUTE";
		case (WR_C_ATTR | (OPCODE_LUT << 0x4)):      return "INDIRECT_LUT_WR_C";
		// default: return "None";
	}
	if(opcode>=low_acc) return "INDIRECT_LUT_COMPUTE";
	else if(opcode<=high_acc) return "INDIRECT_LUT_COMPUTE";
}

static inline void PIM_RD_INSTR(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode) 
{
	pim_isa[*idx].next_l = *next;
	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = HIGH_ADDR;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = 0x0U;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

static inline void PIM_WR_INSTR(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode) 
{
	pim_isa[*idx].next_l = *next;
	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = 0x0U;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = HIGH_ADDR;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

static inline void PIM_RD_INSTR_INDRC(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode, uint32_t ucode) 
{
	if(ucode == 1) pim_isa[*idx].next_l = *next|0x3;
	else if(ucode == 2) pim_isa[*idx].next_l = *next|0x5;
	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = HIGH_ADDR;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = 0x0U;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

static inline void PIM_WR_INSTR_INDRC(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode, uint32_t ucode) 
{
	if(ucode == 1) pim_isa[*idx].next_l = *next|0x3;
	else if(ucode == 2) pim_isa[*idx].next_l = *next|0x5;

	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = 0x0U;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = HIGH_ADDR;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

static inline void PIM_RD_INSTR_LUT(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode) 
{
	pim_isa[*idx].next_l = *next|0x3;
	// pim_isa[*idx].next_l = *next;
	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = HIGH_ADDR;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = HIGH_ADDR;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

static inline void DUMMY_INSTR(uint32_t *idx, uint32_t *next, 
							 uint32_t src, uint32_t dst, uint32_t length, uint32_t opcode) 
{
	pim_isa[*idx].next_l = *next;
	pim_isa[*idx].next_h = HIGH_ADDR;
	pim_isa[*idx].src_l = src;
	pim_isa[*idx].src_h = HIGH_ADDR;
	pim_isa[*idx].dst_l = dst;
	pim_isa[*idx].dst_h = HIGH_ADDR;
	pim_isa[*idx].len = length;
	pim_isa[*idx].status = 0x0U | opcode;
    // PIM_MATH_LOG("    PIM_ISA[idx:%3d] next:%x | src:%10x | dst:%10x | length: %6x | opcode: %s\n", 
    // 							*idx, pim_isa[*idx].next_l, pim_isa[*idx].src_l, pim_isa[*idx].dst_l, pim_isa[*idx].len, decode_opcode(opcode));
    (*idx)++;
    (*next)+=0x40;
}

#endif
