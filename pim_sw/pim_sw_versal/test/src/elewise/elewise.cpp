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
#include "convert_numeric.h"

#define  PL_DMA "/dev/pl_dma"

struct timespec start_DMA, end_DMA;
struct timespec start_CPU, end_CPU;
uint64_t diff_DMA;
uint64_t diff_CPU;
int iter;

void elewise_add_CPU(float *src_A_DRAM, float * src_B_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  
  for(int i=0; i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = src_A_DRAM[i] + src_B_DRAM[i];
  }
}

void elewise_sub_CPU(float *src_A_DRAM, float * src_B_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  
  for(int i=0; i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = src_A_DRAM[i] - src_B_DRAM[i];
  }
}

void elewise_mul_CPU(float *src_A_DRAM, float * src_B_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  
  for(int i=0; i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = src_A_DRAM[i] * src_B_DRAM[i];
  }
}

int main(int argc, char *argv[])
{

    if(argc<2)
    {
        printf("Check vector param p,q,r (pxq) +-x (pxq) = (pxq)\n");
        exit(1);
    }
    
    int p_size = atoi(argv[1]);
    int q_size = atoi(argv[2]);
    int r_size = q_size;

    int srcA_size = p_size * q_size;
    int srcB_size = p_size * q_size;
    int dstC_size = p_size * q_size;

    int tmp=0;

    int fd_dma=0;
    int fd_conf=0;

    if ((fd_dma=open( PL_DMA, O_RDWR|O_SYNC)) < 0) {
        perror(" PL_DMA open error");
        exit(-1);
    }

    short *PL_srcA_buf = (short *)pim_malloc(srcA_size*sizeof(short));
    short *PL_srcB_buf = (short *)pim_malloc(srcB_size*sizeof(short));
    short *PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));
    //short *PL_srcA_buf = (short *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | 0x40, -1, 0));
    //short *PL_srcB_buf = (short *)(mmap(NULL, srcB_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | 0x40, -1, 0));
    //short *PL_dstC_buf = (short *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | 0x40, -1, 0));
    if (PL_srcA_buf == MAP_FAILED) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (PL_srcB_buf == MAP_FAILED) {
        printf("PL srcB call failure.\n");
        return -1;
    }
    if (PL_dstC_buf == MAP_FAILED) {
        printf("PL dstC call failure.\n");
        return -1;
    }

    //zeroing
    for(size_t i=0; i<srcA_size; i++){
      PL_srcA_buf[i]=0;
    }
    for(size_t i=0; i<srcB_size; i++){
      PL_srcB_buf[i]=0;
    }
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i]=0;
    }

    //For CPU verify
    float *src_A_DRAM = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *src_B_DRAM = (float *)(mmap(NULL, srcB_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *dst_C_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    // Input data
    srand((unsigned int)time(NULL));  // For reset random seed
    
    printf("srcA init\n");
    for(size_t i=0; i<srcA_size; i++){
      float tmp  = generate_random();
      //float tmp  = 0.5;
      short tmp0 = float_to_short(tmp);
      PL_srcA_buf[i] = tmp0;
      src_A_DRAM[i] = short_to_float(tmp0);
    }

    printf("srcB init\n");
    for(size_t i=0; i<srcB_size; i++){
      float tmp  = generate_random_255();
      //float tmp  = 0.01625;
      short tmp0 = float_to_short(tmp);
      PL_srcB_buf[i]=tmp0;
      src_B_DRAM[i] = short_to_float(tmp0);
    }    
    
    printf("dstC init\n");
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i]=0;
      dst_C_DRAM[i] = 0;
    }

    //check CPU result
    printf("check cpu elewise\n");
    elewise_add_CPU(src_A_DRAM, src_B_DRAM, dst_C_DRAM, p_size, q_size);
    //elewise_sub_CPU(src_A_DRAM, src_B_DRAM, dst_C_DRAM, p_size, q_size);
    //elewise_mul_CPU(src_A_DRAM, src_B_DRAM, dst_C_DRAM, p_size, q_size);

    pim_args *set_info;
    int size = sizeof(pim_args);
    set_info = (pim_args *)malloc(size);

    set_info->srcA_ptr  = PL_srcA_buf;
    set_info->srcB_ptr  = PL_srcB_buf;
    set_info->dstC_ptr  = PL_dstC_buf;    
    set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0];
    set_info->srcB_va   = (uint64_t)&PL_srcB_buf[0];
    set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0];
    set_info->srcA_size = srcA_size*sizeof(short);
    set_info->srcB_size = srcB_size*sizeof(short);
    set_info->dstC_size = dstC_size*sizeof(short);
    set_info->p_size    = p_size;
    set_info->q_size    = q_size;
    set_info->r_size    = r_size;
    //set_info->dummy_buf_PA = BRAM_DUMMY;

    //ioctl(fd_dma, TIME_INIT, set_info);
    init_pim_drv();
    clock_gettime(CLOCK_MONOTONIC, &start_DMA);
    elewise_add(set_info);
    clock_gettime(CLOCK_MONOTONIC, &end_DMA);  

    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);
    
    //printf("--------------------------------------\r\n");
    /////////////////////////////////////////////////////////////////////////////////////////////////

    union converter{
    float f_val;
    unsigned int u_val;
    };
    union converter a;
    union converter b;

    printf("Correctness check!\n\n");
    printf("       HOST       |  ARM\n");
    for(int i=0; i<dstC_size; i++){ 
        a.f_val = dst_C_DRAM[i];

        printf("idx[%4d] 0x%x  |  ", i, a.u_val);
        printf("0x%x ", PL_dstC_buf[i]);
        printf("\n");
    }
    printf("\n");

    //uint64_t *prof_buf = (uint64_t *)pim_malloc(4096);
    //set_info->dstC_ptr = prof_buf;
    //set_info->dstC_va   = (uint64_t)&prof_buf[0];    
    //if (ioctl(fd_dma, PROF_CNT_READ, set_info) < 0) {
    //    printf("ERROR read profiling counter \n");
    //    return 0;        
    //}
    printf("PIM] execution time %llu nanoseconds\n", (long long unsigned int) diff_DMA);    
    //printf("PIM] CYCLE %llu%llu \n", prof_buf[1], prof_buf[0]);
    //uint64_t vm_time = ioctl(fd_dma, GET_EWAdd_TIME, set_info);
    //printf("PIM] VM_TIME %llu\n", vm_time);    
    return 0;
}




