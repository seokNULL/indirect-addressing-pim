#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h> 
#include <stdint.h>

#include <sys/ioctl.h>
#include <stdbool.h>
#include <pim.h>
#include "matmul.h"
#include "util.h"

#define NUM_BANK 16
#define REG_SIZE 16



void matmul_decoupled_pim_initialize(float *A, float *B, short *pim_A, short *pim_B, size_t M, size_t K, size_t N) {
  int p_size = M;
  int q_size = K;
  int r_size = N;
  if(p_size <16){
    perror("Tiling factor of decoupled-PIM is p_size>16");
  }

  int A_ROW = p_size;
  int A_COL = q_size;
  int B_COL = r_size;
  int A_ROW_PAD, A_COL_PAD, B_COL_PAD;
  A_ROW_PAD = (A_ROW + REG_SIZE - 1) / REG_SIZE * REG_SIZE;
  A_COL_PAD = (A_COL + REG_SIZE - 1) / REG_SIZE * REG_SIZE;
  B_COL_PAD = (B_COL + NUM_BANK - 1) / NUM_BANK * NUM_BANK;
  int cnt = 0;
  size_t idx = 0;

 //Input matrix A tiling
    for (size_t io = 0; io < A_ROW_PAD; io += REG_SIZE) {
      for (size_t k = 0; k < A_COL_PAD; k++) {
        for (size_t ii = 0; ii < REG_SIZE; ii++) {
            float tmp =A[(io + ii) * A_COL + k];
            short tmp0 = float_to_short(tmp);
              if (io + ii < A_ROW && k < A_COL) {
                pim_A[idx] = tmp0;
              }
              else {
                pim_A[idx] = 0;
              }
            cnt += 1;
            idx += 1;
        }
      }
    }
//Weight matrix B tiling
    cnt = 0;
    for (size_t jo = 0; jo < B_COL_PAD; jo += NUM_BANK) {
      for (size_t ko = 0; ko < A_COL_PAD; ko += NUM_BANK) {
        for (size_t ji = 0; ji < REG_SIZE; ji++) {
          for (size_t ki = 0; ki < REG_SIZE; ki++) {
            float tmp = B[(ko + ki) * B_COL + (jo + ji)];
            short tmp0 = float_to_short(tmp);
              if (ko + ki < A_COL && jo + ji < B_COL) {
                  pim_B[cnt] = tmp0;
              }
              else {
                  pim_B[cnt] = 0;
              }
            cnt += 1;
          }
        }
      }
    }
}


void matmul_decoupled_pim_finalize(short *A, short *B, short *C, size_t M, size_t N, size_t K) {
  int p_size = M;
  int q_size = K;
  int r_size = N;
  int A_ROW = p_size;
  int A_COL = q_size;
  int B_COL = r_size;
  int A_ROW_PAD, A_COL_PAD, B_COL_PAD;
  A_ROW_PAD = (A_ROW + REG_SIZE - 1) / REG_SIZE * REG_SIZE; 
  A_COL_PAD = (A_COL + REG_SIZE - 1) / REG_SIZE * REG_SIZE;
  B_COL_PAD = (B_COL + NUM_BANK - 1) / NUM_BANK * NUM_BANK;

  int cnt = 0;
//Result layout     
  for (size_t io = 0; io < A_ROW_PAD; io += REG_SIZE) {
    for (size_t j = 0; j < B_COL; j++) {
      for (size_t ii = 0; ii < REG_SIZE; ii++) {
        short tmp = C[cnt];
        C[(io + ii) * B_COL + j] = tmp;
        cnt += 1;
        // printf("cnt:%d & dest:%d\n",cnt, (io + ii) * B_COL + j);
        }
        
      }
  }
}