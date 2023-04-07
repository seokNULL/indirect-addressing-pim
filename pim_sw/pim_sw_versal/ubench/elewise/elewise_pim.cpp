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
#include "elewise.h"
#include "util.h"


static short *PL_srcA_buf;
static short *PL_srcB_buf;
static short *PL_dstC_buf;

void elewise_pim_initialize(float *A, float *B, float *C, size_t M, size_t N) {
  int fd_dma=0;
  init_pim_drv();
  if ((fd_dma=open(PL_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
      perror("PL DMA drvier open");
      exit(-1);
  }
  int p_size = M;
  int q_size = N;
  int r_size = N;
  int srcA_size = p_size * q_size;
  int srcB_size = p_size * r_size;
  int dstC_size = p_size * r_size;  

  //Allocate PIM memory
  PL_srcA_buf = (short *)pim_malloc(srcA_size*sizeof(short));
  PL_srcB_buf = (short *)pim_malloc(srcB_size*sizeof(short));
  PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));
    if (PL_srcA_buf == NULL) {
        printf("PL srcA call failure.\n");
        exit(-1);
    }
    if (PL_srcB_buf == NULL) {
        printf("PL srcB call failure.\n");
        exit(-1);
    }
    if (PL_dstC_buf == NULL) { 
        printf("PL dstC call failure.\n");
        exit(-1);
    }

  //Initialize PIM data
  for(size_t i = 0; i < srcA_size; i++){
    float tmp = A[i];
    short tmp0 = float_to_short(tmp);
    PL_srcA_buf[i] = tmp0;
  }
  for(size_t i = 0; i < srcB_size; i++){
    float tmp  = B[i];
    short tmp0 = float_to_short(tmp);
    PL_srcB_buf[i]=tmp0;
  }    
}

void elewise_pim(float *A, float *B, float *C, size_t M, size_t N, size_t opcode){

  pim_args *set_info;
  uint64_t size = sizeof(pim_args);
  set_info = (pim_args *)malloc(1024*1024*64);
  // set_info = (pim_args *)(mmap(NULL, 1024 * 1024 * size, PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

  set_info->srcA_va = (uint64_t)&PL_srcA_buf[0];
  set_info->srcB_va = (uint64_t)&PL_srcB_buf[0];
  set_info->dstC_va = (uint64_t)&PL_dstC_buf[0];
  set_info->p_size  = M;
  set_info->q_size  = N;
  set_info->r_size  = N;  
  elewise_add(set_info);

  // switch (opcode) {
  //   case 0: elewise_add(set_info); break;
  //   case 1: elewise_sub(set_info); break;
  //   case 2: elewise_mul(set_info); break;
  //   default: break;
  // }
  free(set_info);
}

void elewise_pim_finalize(float *C, size_t M, size_t N) {
  for(size_t i = 0; i< M * N; i++){
      C[i] = short_to_float(PL_dstC_buf[i]);
  }
  pim_free(PL_srcA_buf);
  pim_free(PL_srcB_buf);
  pim_free(PL_dstC_buf);
}