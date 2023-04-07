#pragma once
#include <cstddef>

void elewise_cpu(float *A, float *B, float *C, size_t M, size_t N, size_t opcode);
void elewise_pim(float *A, float *B, float *C, size_t M, size_t N, size_t opcode);


void elewise_cpu_initialize(size_t M, size_t N);
void elewise_pim_initialize(float *A, float *B, float *C, size_t M, size_t N);

void elewise_cpu_finalize(size_t M, size_t N);
void elewise_pim_finalize(float *C, size_t M, size_t N);

