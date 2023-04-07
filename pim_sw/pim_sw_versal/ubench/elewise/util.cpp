#include "util.h"
#include "convert_numeric.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <limits.h>
#include <iostream>
#include <math.h>
#include <bitset>
#include <sys/mman.h>


double get_current_time() {
  struct timespec tv;
  clock_gettime(CLOCK_MONOTONIC, &tv);
  return tv.tv_sec + tv.tv_nsec * 1e-9;
}

void rand_mat(float *m, int R, int S) {
  int N = R * S;
  for (int j = 0; j < N; j++) { m[j] = ((float) rand() / RAND_MAX - 0.5)/10; }
}


void zero_mat(float *m, int R, int S) {
  int N = R * S;
  for(size_t i=0; i<N; i++){
    m[i]=0;
  }
}
void zero_mat(short *m, int R, int S) {
  int N = R * S;
  for(size_t i=0; i<N; i++){
    m[i]=0;
  }
}

void print_mat(float *m, int M, int N) {
  for (int i = 0; i < M; ++i) {
    for (int j = 0; j < N; ++j) { printf("%+.3f ", m[i * N + j]); }
    printf("\n");
  }
}

void check_elewise(short* result_pim, float *C_ans, int M, int N, int opcode) {
  bool is_valid = true;
  int cnt = 0, thr = 10;
  float eps = 1e-1;
  for (int i = 0; i < M; ++i) {
    for (int j = 0; j < N; ++j) {
      float c = short_to_float(result_pim[i * N + j]);
      float c_ans = C_ans[i * N + j];
      if (fabsf(c - c_ans) > eps &&
          (c_ans == 0 || fabsf((c - c_ans) / c_ans) > eps)) {
        ++cnt;
        if (cnt <= thr)
          printf("C[%d][%d] : correct_value = %f, your_value = %f\n", i, j,
                 c_ans, c);
        if (cnt == thr + 1)
          printf("Too many error, only first %d values are printed.\n", thr);
        is_valid = false;
      }
    }
  }

  if (is_valid) {
    printf("Validation Result: VALID\n");
  } else {
    printf("Validation Result: INVALID\n");
  }
  munmap(C_ans, M * N * sizeof(float));
}

void copy_mat_input(float *src, short *dst, int size){
  for(size_t i=0; i<size; i++){
    float tmp  = src[i];
    // float tmp  = 3.5;
    short tmp0 = float_to_short(tmp);
    dst[i] = tmp0;
  }
}

void copy_mat_result(short *src, float *dst, int size){
  for(size_t i=0; i<size; i++){
    short tmp  = src[i];
    // float tmp  = 3.5;
    float tmp0 = short_to_float(tmp);
    dst[i] = tmp0;
  }
}