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
uint64_t diff_DMA2;
uint64_t diff_CPU;
int iter;

void mat_mul_add_CPU(float *src_A_DRAM, float * src_B_DRAM, float * src_2_DRAM, float * dst_C_DRAM, int p_size, int q_size, int r_size)
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

        //if(c_c==0) printf("idx[%lu] a(%x) x b(%x) = c(%x) || acc=%x \n", k, a.u_val, b.u_val, c.u_val, d.u_val);
      }
      dst_C_DRAM[c_c+c_r*r_size]=tmp;
    }
  }
  for(int i=0; i<p_size*r_size;i++)
  {
    dst_C_DRAM[i] = dst_C_DRAM[i] + src_2_DRAM[i];
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

    if ((fd_dma=open( PL_DMA, O_RDWR|O_SYNC)) < 0) {
        perror(" PL_DMA open error");
        exit(-1);
    }

    //For CPU verify
    float *src_A_DRAM = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *src_B_DRAM = (float *)(mmap(NULL, srcB_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *src_2_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
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

    ioctl_info *set_info;
    int size = sizeof(ioctl_info);
    set_info = (ioctl_info *)malloc(size);

    //int type = 1; //only BF16 support
    //if(type==1)
    //{
    //short *PL_srcA_buf = (short *)(mmap(0x0, srcA_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));
    //short *PL_srcB_buf = (short *)(mmap(0x0, srcB_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));
    //short *PL_dstC_buf = (short *)(mmap(0x0, dstC_size*sizeof(short), PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE , -1, 0));  
    short *PL_srcA_buf = (short *)pim_malloc(srcA_size*sizeof(short));
    short *PL_srcB_buf = (short *)pim_malloc(srcB_size*sizeof(short));
    short *temp = (short *)pim_malloc(srcB_size*sizeof(short));
    short *PL_src2_buf = (short *)pim_malloc(dstC_size*sizeof(short));
    short *PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));
    short *PL_dstC2_buf = (short *)pim_malloc(dstC_size*sizeof(short));

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

    if (PL_dstC2_buf == NULL) { 
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
      PL_src2_buf[i]=0;
      PL_dstC2_buf[i]=0;
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

      float tmp  = generate_random_255()/10;
      short tmp0 = float_to_short(tmp);
      PL_src2_buf[i] = tmp0;
      src_2_DRAM[i] = short_to_float(tmp0);      
    }   
    //check CPU result
    printf("check cpu mat mul\n");
    mat_mul_add_CPU(src_A_DRAM, src_B_DRAM, src_2_DRAM, dst_C_DRAM, p_size, q_size, r_size);

    set_info->srcA_ptr  = PL_srcA_buf;
    set_info->srcB_ptr  = PL_srcB_buf;
    set_info->dstC_ptr  = PL_dstC_buf;    
    set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0];
    set_info->srcB_va   = (uint64_t)&PL_srcB_buf[0];
    set_info->bias_va   = (uint64_t)&PL_src2_buf[0];
    set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0];
    set_info->srcA_size = srcA_size*sizeof(short);
    set_info->srcB_size = srcB_size*sizeof(short);
    set_info->src2_size = dstC_size*sizeof(short);
    set_info->dstC_size = dstC_size*sizeof(short);
    set_info->p_size    = p_size;
    set_info->q_size    = q_size;
    set_info->r_size    = r_size;
    set_info->fused_op  = ELEWISE_ADD;
    //ioctl(fd_dma, TIME_INIT, set_info);

    clock_gettime(CLOCK_MONOTONIC, &start_DMA);
    if (ioctl(fd_dma, MATMUL_FUSION, set_info) < 0) {
        printf("ERROR DMA \n");
        return 0;
    }
    clock_gettime(CLOCK_MONOTONIC, &end_DMA);  
    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);

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
    /* To read HW counter */
    //uint64_t *prof_buf = (uint64_t *)pim_malloc(4096);
    //set_info->dstC_ptr = prof_buf;
    //set_info->dstC_va   = (uint64_t)&prof_buf[0];    
    //if (ioctl(fd_dma, PROF_CNT_READ, set_info) < 0) {
    //    printf("ERROR read profiling counter \n");
    //    return 0;        
    //}
    //printf("PROF] READ__CYCLE %llu%llu \n", prof_buf[1], prof_buf[0]);
    //pim_free(prof_buf);
    printf("\n\n");
    printf("Fusion execution time %10llu nanoseconds %d %d %d\n\n\n", (long long unsigned int) diff_DMA, p_size, q_size, r_size);


    set_info->srcA_ptr  = PL_srcA_buf;
    set_info->srcB_ptr  = PL_srcB_buf;
    set_info->dstC_ptr  = PL_dstC_buf;    
    set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0]; //1 32
    set_info->srcB_va   = (uint64_t)&PL_srcB_buf[0]; //32 512
    set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0]; //1  512
    set_info->srcA_size = srcA_size*sizeof(short);
    set_info->srcB_size = srcB_size*sizeof(short);
    set_info->dstC_size = dstC_size*sizeof(short);
    set_info->p_size    = p_size;
    set_info->q_size    = q_size;
    set_info->r_size    = r_size;
    

    clock_gettime(CLOCK_MONOTONIC, &start_DMA);
    if (ioctl(fd_dma, MATMUL, set_info) < 0) {
        printf("ERROR DMA \n");
        return 0;
    }
    clock_gettime(CLOCK_MONOTONIC, &end_DMA);
    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);

    set_info->srcA_ptr  = PL_dstC_buf;
    set_info->srcB_ptr  = PL_dstC_buf;
    set_info->dstC_ptr  = PL_dstC_buf;  

    set_info->srcA_va   = (uint64_t)&PL_dstC_buf[0]; //1 32
    set_info->srcB_va   = (uint64_t)&PL_src2_buf[0]; //32 512
    set_info->dstC_va   = (uint64_t)&PL_dstC2_buf[0]; //1  512
    set_info->srcA_size = dstC_size*sizeof(short);
    set_info->srcB_size = dstC_size*sizeof(short);
    set_info->dstC_size = dstC_size*sizeof(short);
    set_info->p_size    = p_size;
    set_info->q_size    = r_size;
    set_info->r_size    = r_size;

    //clock_gettime(CLOCK_MONOTONIC, &start_DMA); // <-- 1 512 + 1 512
    //if (ioctl(fd_dma, ELEWISE_ADD, set_info) < 0) {
    //    printf("ERROR DMA \n");
    //    return 0;
    //}
    //clock_gettime(CLOCK_MONOTONIC, &end_DMA);
    //diff_DMA2 = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);
    uint64_t total = diff_DMA + diff_DMA2;
    printf("total  execution time %10llu nanoseconds \n", total);
    printf("\n");
    printf("Matmul execution time %10llu nanoseconds %d %d %d\n", (long long unsigned int) diff_DMA, p_size, q_size, r_size);
    printf("Add    execution time %10llu nanoseconds %d %d %d\n", (long long unsigned int) diff_DMA2, p_size, q_size, r_size);    
    close(fd_dma);
    

    pim_free(PL_srcA_buf);
    pim_free(PL_srcB_buf);
    pim_free(PL_dstC_buf);
    return 0;
}




