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


struct timespec start_DMA, end_DMA;
struct timespec start_CPU, end_CPU;
uint64_t diff_DMA;
uint64_t diff_CPU;
int iter;

void mat_mul_CPU(float *src_A_DRAM, float * src_B_DRAM, float * dst_C_DRAM, int p_size, int q_size, int r_size)
{
  
  union converter{
  float f_val;
  unsigned int u_val;
  };
  union converter a;
  union converter b;  
  union converter c;
  union converter d;

  for(size_t c_r=0; c_r < p_size; c_r++)
  {
    for(size_t c_c=0; c_c<r_size; c_c++)
    {
      float tmp=0.0f;
      float mul_tmp=0.0f;
      for(size_t k=0; k<q_size; k++)
      {
        unsigned residual=0;
        if(q_size>32) residual= (q_size-32)*16;

        unsigned row=((k/32)*512)+(c_r*512);
        unsigned col=k%32;

        mul_tmp = (src_A_DRAM[ k + c_r*q_size ] * src_B_DRAM[(k*r_size) + c_c]);

        tmp+=(src_A_DRAM[ k + c_r*q_size ] * src_B_DRAM[(k*r_size) + c_c]);

        a.f_val = src_A_DRAM[ k + c_r*q_size ];
        b.f_val = src_B_DRAM[(k*r_size) + c_c];
        c.f_val = mul_tmp;
        d.f_val = tmp;

        if(c_c==0) printf("idx[%lu] a(%x) x b(%x) = c(%x) || acc=%x \n", k, a.u_val, b.u_val, c.u_val, d.u_val);
      }
      dst_C_DRAM[c_c+c_r*r_size]=tmp;
    }
  }
}

int main(int argc, char *argv[])
{

    if(argc<2)
    {
        printf("Check matrix param p,q,r (pxq) x (qxr) = (pxr)\n");
        exit(1);
    }
    
    int p_size = atoi(argv[1]);
    int q_size = atoi(argv[2]);
    int r_size = atoi(argv[3]);

    //int cmd = atoi(argv[4]);
    //int type = atoi(argv[5]);

    int srcA_size = p_size * q_size;
    int srcB_size = q_size * r_size;
    int dstC_size = p_size * r_size;

    int tmp=0;

    int fd_dma=0;
    int fd_conf=0;

    init_pim_drv();
    if ((fd_dma=open(PL_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
        perror("PL DMA drvier open");
        exit(-1);
    }

    //For CPU verify
    float *src_A_DRAM = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *src_B_DRAM = (float *)(mmap(NULL, srcB_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *dst_C_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    srand((unsigned int)time(NULL));  // For reset random seed

    void *srcA;
    void *srcB;
    void *dstC;

    uint64_t srcA_va;
    uint64_t srcB_va;
    uint64_t dstC_va;

    uint64_t prev_matmul_dma_tx=1024;
    uint64_t prev_elewise_dma_tx=0;
    
    //uint64_t dummy_buf_PA;

    pim_args *set_info;
    int size = sizeof(pim_args);
    set_info = (pim_args *)malloc(size);

    //int type = 1; //only BF16 support
    //if(type==1)
    //{
    //short *PL_srcA_buf = (short *)(mmap(0x0, srcA_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));
    //short *PL_srcB_buf = (short *)(mmap(0x0, srcB_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));
    //short *PL_dstC_buf = (short *)(mmap(0x0, dstC_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));  
    short *PL_srcA_buf = (short *)pim_malloc(srcA_size*sizeof(short));
    short *PL_srcB_buf = (short *)pim_malloc(srcB_size*sizeof(short));
    short *PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));

    if (PL_srcA_buf == NULL) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (PL_srcB_buf == NULL) {
        printf("PL srcB call failure.\n");
        return -1;
    }
    if (PL_dstC_buf == NULL) { 
        printf("PL dstC call failure.\n");
        return -1;
    }

    printf("Complete pim_malloc\n");
    uint64_t A_pa = VA2PA((uint64_t)&PL_srcA_buf[0]);    
    uint64_t B_pa = VA2PA((uint64_t)&PL_srcB_buf[0]);    
    uint64_t C_pa = VA2PA((uint64_t)&PL_dstC_buf[0]);    
    printf("A:%llx \n", A_pa);
    printf("B:%llx \n", B_pa);
    printf("C:%llx \n", C_pa);
    getchar();

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

    printf("srcA init\n");
    for(size_t i=0; i<srcA_size; i++){
      float tmp  = generate_random()/10;
      short tmp0 = float_to_short(tmp);
      PL_srcA_buf[i] = tmp0;
      src_A_DRAM[i] = short_to_float(tmp0);
    }

    printf("srcB init (%d)\n", srcB_size);
    for(size_t i=0; i<srcB_size; i++){
      float tmp  = generate_random_255()/10;
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
    printf("check cpu mat mul\n");
    clock_gettime(CLOCK_MONOTONIC, &start_CPU);
    mat_mul_CPU(src_A_DRAM, src_B_DRAM, dst_C_DRAM, p_size, q_size, r_size);
    clock_gettime(CLOCK_MONOTONIC, &end_CPU);  

    set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0];
    set_info->srcB_va   = (uint64_t)&PL_srcB_buf[0];
    set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0];
    set_info->p_size    = p_size;
    set_info->q_size    = q_size;
    set_info->r_size    = r_size;   
    
    
    printf("Enter to start PIM");
    getchar();

    clock_gettime(CLOCK_MONOTONIC, &start_DMA);
    matmul(set_info);
    clock_gettime(CLOCK_MONOTONIC, &end_DMA);  


    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);
    printf("PIM execution time %llu nanoseconds %d %d %d\n", (long long unsigned int) diff_DMA, p_size, q_size, r_size);
    diff_CPU = BILLION * (end_CPU.tv_sec - start_CPU.tv_sec) + (end_CPU.tv_nsec - start_CPU.tv_nsec);
    printf("CPU execution time %llu nanoseconds %d %d %d\n", (long long unsigned int) diff_CPU, p_size, q_size, r_size);
    
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
        if (i == 32) // Only Bank 0
            break;
    }
    printf("\n"); 
    pim_free(PL_srcA_buf);
    pim_free(PL_srcB_buf);
    pim_free(PL_dstC_buf);
    return 0;
}



