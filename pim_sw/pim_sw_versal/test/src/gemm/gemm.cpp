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

void gemm_CPU(float *src_A_DRAM, float * src_B_DRAM, float * src_bias_DRAM, float * dst_C_DRAM, int p_size, int q_size, int r_size)
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

        //if(c_c==0) printf("idx[%d] a(%x) x b(%x) = c(%x) || acc=%x \n", k, a.u_val, b.u_val, c.u_val, d.u_val);
      }
      // dst_C_DRAM[c_c+c_r*r_size]=tmp;
      // dst_C_DRAM[c_c+c_r*r_size]=tmp + src_bias_DRAM[(c_c+c_r*r_size)%r_size];
      dst_C_DRAM[c_c+c_r*r_size]=tmp + src_bias_DRAM[(c_c+c_r*r_size)];
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
    int bias_size = p_size * r_size;

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
    float *src_bias_DRAM = (float *)(mmap(NULL, bias_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    float *dst_C_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    srand((unsigned int)time(NULL));  // For reset random seed

    void *srcA;
    void *srcB;
    void *bias;
    void *dstC;

    uint64_t srcA_va;
    uint64_t srcB_va;
    uint64_t dstC_va;
    uint64_t bias_pa;

    // uint64_t prev_matmul_dma_tx=1024;
    // uint64_t prev_elewise_dma_tx=0;
    
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
    short *PL_bias_buf = (short *)pim_malloc(bias_size*sizeof(short));

    short *PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));

    if (PL_srcA_buf == NULL) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (PL_srcB_buf == NULL) {
        printf("PL srcB call failure.\n");
        return -1;
    }
    if (PL_bias_buf == MAP_FAILED) {
        printf("PL bias call failure.\n");
        return -1;
    }      
    if (PL_dstC_buf == NULL) { 
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
    for(size_t i=0; i<bias_size; i++){
      PL_bias_buf[i]=0;
    }    
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i]=0;
    }

    printf("srcA init\n");
    for(size_t i=0; i<srcA_size; i++){
      float tmp  = generate_random()/10;
      // float tmp  = 0.01625;
      short tmp0 = float_to_short(tmp);
      PL_srcA_buf[i] = tmp0;
      src_A_DRAM[i] = short_to_float(tmp0);
    }

    printf("srcB init (%d)\n", srcB_size);
    for(size_t i=0; i<srcB_size; i++){
      float tmp  = generate_random_255()/10;
      // float tmp  = 0.01625;
      short tmp0 = float_to_short(tmp);
      PL_srcB_buf[i]=tmp0;
      src_B_DRAM[i] = short_to_float(tmp0);
    }    
    printf("Bias init\n");
    for(size_t i=0; i<bias_size; i++){
      float tmp  = generate_random_255();
      // float tmp  = 0.01625;
      short tmp0 = float_to_short(tmp);
      PL_bias_buf[i]=tmp0;
      src_bias_DRAM[i] = short_to_float(tmp0);
    }       
    printf("dstC init\n");
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i]=0;
      dst_C_DRAM[i] = 0;
    }

    //sleep(1); // need flush
    //
    //short *dummy = (short *)(mmap(NULL, 1024*1024*8*sizeof(short), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    //int i=0;
    //for(i=0;i<1024*1024*8;i++){
    //    dummy[i] = 0;
    //}        
    //
    //sleep(1); // need flush

    //printf("press\r\n");
    //getchar();

    //printf("srcA init test\n");
    //for(size_t i=0; i<srcA_size; i++){
    //  printf("srcA[%d]=%x\r\n", i,  PL_srcA_buf[i]);
    //}
    //
    //printf("srcB init test\n");
    //for(size_t i=0; i<srcB_size; i++){
    //  printf("srcB[%d]=%x\r\n", i,  PL_srcB_buf[i]);
    //}    
    bool r_need_align = r_size % 512 != 0;
    int r_pad_size = r_need_align ? 512 * (r_size / 512 + 1) : r_size;
    short *align_transB_PL_ptr = nullptr;
    short *padded_transB_PL_ptr = nullptr;

    padded_transB_PL_ptr = (short *)pim_malloc(q_size * r_pad_size * sizeof(Bfloat16));
    align_transB_PL_ptr = (short *)pim_malloc(q_size * r_pad_size * sizeof(Bfloat16));
    
    for(size_t i=0; i< (q_size*r_pad_size); i++){
      padded_transB_PL_ptr[i]=0;
      align_transB_PL_ptr[i] = 0;
    }

    if (r_size != 512 && r_size > 512) {
        // 1. pad
        for (int k = 0; k < q_size; k++) {
            for (int n = 0; n < r_size; n++) {
                padded_transB_PL_ptr[k*r_pad_size+n] = PL_srcB_buf[k*r_size+n];
            }
        }
        int CHUNK = 512;
        int row_dim = q_size;
        int col_dim = r_pad_size;
        int col_chunk_num = col_dim / CHUNK;
        int dest_idx = 0;
        // 2. align
        for (int i = 0; i < col_chunk_num; i++) {
          for (int j = 0; j < row_dim; j++) {
              for (int k = 0; k < CHUNK; k++) {
                  align_transB_PL_ptr[dest_idx] = padded_transB_PL_ptr[(i*CHUNK)+(j*col_dim)+k];
                  // std::cout << "dest_idx: "<< dest_idx << "\tsrc_index: " << (i*CHUNK)+(j*col_dim)+k << std::endl;
                  dest_idx++;
              }
          }
        }     
    }
    
    
    //check CPU result
    printf("check cpu mat mul\n");
    gemm_CPU(src_A_DRAM, src_B_DRAM, src_bias_DRAM, dst_C_DRAM, p_size, q_size, r_size);

    int bias_size_padded = p_size * r_pad_size;
    short *PL_bias_buf_padded = (short *)pim_malloc(bias_size_padded*sizeof(short));
    for(size_t i=0; i< bias_size_padded; i++){
      PL_bias_buf_padded[i]=0;
    }
    
    for(size_t i=0; i<p_size; i++){
      for(size_t j=0; j<r_pad_size; j++){
        if(j<r_size)
        PL_bias_buf_padded[i*r_pad_size + j] = PL_bias_buf[i*r_size+j];
        else
        PL_bias_buf_padded[i*r_pad_size + j] = 0;
      }
    }

    short* aligned_Y_PL_ptr = nullptr;
        aligned_Y_PL_ptr = (short *)pim_malloc(p_size * r_pad_size * sizeof(Bfloat16));

    short *mat_B = (r_need_align)? align_transB_PL_ptr: PL_srcB_buf;
    short *mat_A = PL_srcA_buf;
    short *mat_bias = (r_need_align)? PL_bias_buf_padded: PL_bias_buf;
    short *mat_result = (r_need_align)? aligned_Y_PL_ptr: PL_dstC_buf;


    set_info->srcA_ptr      = PL_srcA_buf;
    set_info->srcB_ptr      = mat_B;
    set_info->srcbias_ptr   = mat_bias;
    set_info->dstC_ptr      = mat_result;
    set_info->srcA_va       = (uint64_t)&PL_srcA_buf[0];
    set_info->srcB_va       = (uint64_t)&mat_B[0];
    set_info->bias_va       = (uint64_t)&mat_bias[0];
    set_info->dstC_va       = (uint64_t)&mat_result[0];

    set_info->srcA_size     = p_size * q_size*sizeof(short);
    set_info->srcB_size     = q_size * r_pad_size * sizeof(short);
    set_info->dstC_size     = p_size * r_pad_size * sizeof(short);
    set_info->p_size        = p_size;
    set_info->q_size        = q_size;
    set_info->r_size        = r_pad_size;
    

    clock_gettime(CLOCK_MONOTONIC, &start_DMA);

    printf("Start PIM \n");
    if (ioctl(fd_dma, GEMM, set_info) < 0) {
        printf("ERROR DMA \n");
        return 0;
    }
    //ioctl(fd_dma, SG_MODE_MATMUL_CONT_8PAGE, set_info);
    //ioctl(fd_dma, SG_MODE_MATMUL_CONT_PAGE, set_info);

    clock_gettime(CLOCK_MONOTONIC, &end_DMA);  
    
    if (r_size % 512 != 0) {
        for (int m = 0; m < p_size; m++) {
            for (int n = 0; n < r_size; n++) {
                PL_dstC_buf[r_size * m + n] = aligned_Y_PL_ptr[r_pad_size * m + n];
            }
        }        
    }


    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);
    printf("PIM execution time %llu nanoseconds %d %d %d\n", (long long unsigned int) diff_DMA, p_size, q_size, r_size);
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
        // if (i == 32) // Only Bank 0
            // break;
    }
    printf("\n"); 

    close(fd_dma);
    
    pim_free(PL_srcA_buf);
    pim_free(PL_srcB_buf);
    pim_free(PL_bias_buf);
    pim_free(PL_bias_buf_padded);

    pim_free(PL_dstC_buf);
    return 0;
}



