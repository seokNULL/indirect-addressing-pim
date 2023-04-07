#pragma once

#include <cstddef>
// #include <pim.h>

short* matmul_pim_initialize(short *srcB_pim, size_t row_size, size_t col_size);
void matmul_decoupled_pim_initialize(float *A, float *B, short *pim_A, short *pim_B, size_t M, size_t K, size_t N);
void pim_align(short *src, short *dst, int row_dim, int col_dim);

void matmul_cpu_finalize(size_t M, size_t N, size_t K);
void matmul_pim_finalize(short *A, short *B, short *C, size_t M, size_t N, size_t K);
void matmul_decoupled_pim_finalize(short *A, short *B, short *C, size_t M, size_t N, size_t K);

