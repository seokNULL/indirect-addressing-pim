#include <cstdlib>

#include "elewise.h"

void elewise_cpu_initialize(size_t M, size_t N) {
  // Nothing to do
  return;
}

void elewise_cpu(float *A, float *B, float *C, size_t M, size_t N, size_t opcode) {
  
  //0: Addition
  //1: Subtraction
  //2: Multiplication
  switch (opcode) {
    case 0: 
    {
      for (int i = 0; i < M; ++i) {
        for (int j = 0; j < N; ++j) {
          C[i * N + j] = A[i * N + j] + B[i * N + j];
        }
      }
      break;
    }
    case 1: 
    {
      for (int i = 0; i < M; ++i) {
        for (int j = 0; j < N; ++j) {
          C[i * N + j] = A[i * N + j] - B[i * N + j];
        }
      }
      break;
    }
    case 2: 
    {
      for (int i = 0; i < M; ++i) {
        for (int j = 0; j < N; ++j) {
          C[i * N + j] = A[i * N + j] * B[i * N + j];
        }
      }
      break;
    }
    default: break;
  }
}

void elewise_cpu_finalize(size_t M, size_t N) {
  // Nothing to do
  return;
}
