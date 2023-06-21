#include "pim_math.h"
#include <time.h>

int _matmul_indirect_silent(pim_args *pim_args);
int _generate_indirect_matmul_code(pim_args *pim_args);

int _generate_lut_code(pim_args *pim_args);
int _lut_op(pim_args *pim_args);

int matmul_indirect(pim_args *pim_args) {
    return _matmul_indirect_silent(pim_args);
}
int generate_indirect_matmul_code(pim_args *pim_args) {
    return _generate_indirect_matmul_code(pim_args);
}

int generate_indirect_lut_code(pim_args *pim_args){
    return _generate_lut_code(pim_args);
}
int lut_op(pim_args *pim_args){
    return _lut_op(pim_args);
}


int _generate_indirect_matmul_code(pim_args *pim_args)
{

    uint32_t desc_idx, next_desc, r_loop_var, p, q, r;
    uint32_t p_size, q_size, r_size;
    uint32_t A_off, B_off, C_off;
    uint32_t A_len, B_len, C_len;

    // uint32_t B_iter;

    A_len = BURST_SIZE;
    B_len = REG_SIZE * PIM_WIDTH;
    C_len = PIM_WIDTH;

    // srcA_va = pim_args->srcA_va;
    // srcB_va = pim_args->srcB_va;
    // dstC_va = pim_args->dstC_va;

    p_size = pim_args->p_size;
    q_size = pim_args->q_size;
    r_size = pim_args->r_size;
    r_loop_var = (r_size * TYPE_SIZE) / PIM_WIDTH;

    desc_idx = 0;
    next_desc = desc_base + 0x40;

    // B_iter = 0;

    PIM_MATH_LOG("%s: p:%d, q:%d, r:%d\n", __func__, p_size, q_size, r_size);
    for (p = 0; p < p_size; p++) {
        for(r = 0; r < r_loop_var; r++){
            for(q = 0; q < q_size; q = q + REG_SIZE){
                PIM_MATH_LOG("[p:%d, q:%d, r:%d] \n", p, q, r);
                A_off = (q * TYPE_SIZE) + (p * (q_size * TYPE_SIZE));
                B_off = (r * (q_size * PIM_WIDTH)) + (q * PIM_WIDTH);
                /* 
                 * DMA bus width is 512. The transfer size of RD_A is the same as BURST_SIZE. 
                 * Therefore, if BURST_SIZE is 32B, the address of RD_A increases by 0x20. 
                 * Therefore, the offset of source and destination (dummy address) must increase together due to un-aligned error in DMA engine IP.
                 */
                PIM_RD_INSTR_INDRC(&desc_idx, (&next_desc), A_off, BRAM_DUMMY + (A_off % 0x40), A_len, RD_A_ATTR | (OPCODE_MAT_MUL << 0x4), 1);
                PIM_RD_INSTR_INDRC(&desc_idx, &next_desc, B_off, BRAM_DUMMY + (B_off % 0x40), B_len, RD_B_ATTR | (OPCODE_MAT_MUL << 0x4), 1);
                
            }
            C_off = (r * PIM_WIDTH) + (p * (r_size * TYPE_SIZE));
	    PIM_WR_INSTR_INDRC(&desc_idx, &next_desc, BRAM_DUMMY + (C_off % 0x40), C_off, C_len, WR_C_ATTR | (OPCODE_MAT_MUL << 0x4), 1); //C_off
	    // PIM_WR_INSTR(&desc_idx, &next_desc, BRAM_DUMMY + (C_off % 0x40), C_pa, C_len, WR_C_ATTR | (OPCODE_MAT_MUL << 0x4));
        }
    }
    pim_args->desc_idx = desc_idx - 1;
    pim_args->desc_last = next_desc - 0x40;
    if (indirect_code_load(pim_args) < 0) {
        return -1;
    }

    return 0;
}

int _matmul_indirect_silent(pim_args *pim_args)
{
    if (pim_exec_indirect(pim_args) < 0) {
        return -1;
    }

    return 0;
}

int _generate_lut_code(pim_args *pim_args)
{

	uint32_t desc_idx, next_desc, p_loop_var, r_loop_var, p, r, i;
	uint32_t p_size, r_size;
    uint64_t A_pa, B_pa, C_pa, offset;
    uint64_t C_base;
	uint64_t srcB_va, dstC_va;
    uint32_t acc_id, bank_id;
    uint32_t ACC_SIZE = 32;
    uint32_t acc_opcode = 0;
    uint32_t bank_id_arr [16] = {0, 4, 8, 12,
                                 1, 5, 9, 13,
                                 2, 6, 10, 14,
                                 3, 7, 11, 15};
	// srcA_va = pim_args->srcA_va;
    srcB_va = pim_args->srcB_va;
    dstC_va = pim_args->dstC_va;

    p_size = pim_args->p_size;
    r_size = pim_args->r_size;

	desc_idx = 0;
    next_desc = desc_base + 0x40;

    p_loop_var = p_size;
    r_loop_var = r_size;
    // A_base = 0x0ULL;
    // B_base = 0x0ULL;
    C_base = 0x0ULL;

       
    PIM_MATH_LOG("%s: p:%d, r:%d\n", __func__, p_size, r_size);

    // B_pa = VA2PA(srcB_va);

    for (p = 0; p < p_loop_var; p++){
        for(r = 0; r < r_loop_var; r = r + (REG_SIZE * NUM_BANKS)){
            PIM_MATH_LOG("[p:%d, r:%d] \n", p, r);
            // offset = (p * r_size_aligned * TYPE_SIZE) + (r * TYPE_SIZE);
            offset = (p * r_size * TYPE_SIZE) + (r * TYPE_SIZE);
            if ((offset % HUGE_PAGE_SIZE) == 0) {
                C_base = VA2PA(dstC_va + offset);
                C_pa = C_base;
                // A_base = VA2PA(offset);
                A_pa = offset;

            } else {
                // A_pa = A_base + offset;
                C_pa = C_base + offset;
                A_pa = offset;
            }
            PIM_RD_INSTR_LUT(&desc_idx, &next_desc, A_pa, LUT_READ_INPUT, PIM_WIDTH, RD_A_ATTR | (OPCODE_LUT << 0x4));
          for(i=0;i<16;i++){
            bank_id = bank_id_arr[i];
            for(acc_id=0; acc_id<16; acc_id++){
            //    acc_opcode = (bank_id<<28) | (acc_id<<24);
               acc_opcode = (bank_id<<25) | (acc_id<<21);
               PIM_RD_INSTR_INDRC(&desc_idx, &next_desc, A_pa, BRAM_DUMMY, ACC_SIZE, (acc_opcode) | RD_B_ATTR | (OPCODE_LUT << 0x4), 2);
            }
          }
       
            PIM_WR_INSTR(&desc_idx, &next_desc, BRAM_DUMMY, C_pa, PIM_WIDTH, WR_C_ATTR | (OPCODE_LUT << 0x4));
        }
    }

    // for (p = 0; p < p_loop_var; p++){
    //     for(r = 0; r < r_loop_var; r = r + (REG_SIZE * NUM_BANKS)){
    //         PIM_MATH_LOG("[p:%d, r:%d] \n", p, r);
    //         // offset = (p * r_size_aligned * TYPE_SIZE) + (r * TYPE_SIZE);
    //         offset = (p * r_size * TYPE_SIZE) + (r * TYPE_SIZE);
    //         if ((offset % HUGE_PAGE_SIZE) == 0) {
    //             A_base = VA2PA(srcA_va + offset);
    //             B_base = VA2PA(srcB_va + offset);
    //             C_base = VA2PA(dstC_va + offset);
    //             A_pa = A_base;
    //             B_pa = B_base;
    //             C_pa = C_base;
    //         } else {
    //             A_pa = A_base + offset;
    //             B_pa = B_base + offset;
    //             C_pa = C_base + offset;
    //         }
    //         PIM_RD_INSTR(&desc_idx, &next_desc, A_pa, BRAM_DUMMY, PIM_WIDTH, RD_A_ATTR | (OPCODE_MAT_MUL << 0x4));
    //         PIM_RD_INSTR(&desc_idx, &next_desc, B_pa, BRAM_DUMMY, LUT_WIDTH, RD_B_ATTR | (OPCODE_MAT_MUL << 0x4));
    //         PIM_WR_INSTR(&desc_idx, &next_desc, BRAM_DUMMY, C_pa, PIM_WIDTH, WR_C_ATTR | (OPCODE_MAT_MUL << 0x4));
    //     }
    // }

    pim_args->desc_idx = desc_idx - 1;
    pim_args->desc_last = next_desc - 0x40;
    if (indirect_code_load(pim_args) < 0) {
        return -1;
    }

    return 0;
}

int _lut_op(pim_args *pim_args)
{
    if (pim_exec_indirect(pim_args) < 0) {
        return -1;
    }

    return 0;
}
