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

#include <fstream>
#include <string>
#include <vector>

struct timespec start_DMA, end_DMA;
struct timespec start_CPU, end_CPU;
uint64_t diff_DMA;
uint64_t diff_CPU;
int iter;

#define CMD_DIV  1
#define CMD_SQRT 2
#define CMD_ERF  3
#define CMD_EXP  4
#define CMD_LOG  5
#define CMD_POW  6

#define CMD_RELU         7
#define CMD_SILU         8
#define CMD_SIGMOID      9
#define CMD_GELU         10
#define CMD_HARDSWISH    11
#define CMD_LRELU        12
#define CMD_TANH         13
#define CMD_HARDSIGMOID  14
#define CMD_ELU          15

void elewise_erf_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float)erf(src_A_DRAM[i]);
  }
}
void elewise_div_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  
  for(int i=0; i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float) 1.0f/src_A_DRAM[i];
  }
}
void elewise_sqrt_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float)sqrt(src_A_DRAM[i]);
  }
}
void elewise_exp_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float)exp(src_A_DRAM[i]);
  }
}
void elewise_log_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float)log(src_A_DRAM[i]);
  }
}
void elewise_pow_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    dst_C_DRAM[i] = (float)pow(2,src_A_DRAM[i]);
  }
}
void elewise_ReLU_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    if(x>0) dst_C_DRAM[i] = x;
    else    dst_C_DRAM[i] = x;
  }
}

void elewise_SiLU_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    dst_C_DRAM[i] = x/(1+exp(-x));
  }
}

void elewise_sigmoid_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    dst_C_DRAM[i] = 1/(1+exp(-x));
  }
}


void elewise_GeLU_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    dst_C_DRAM[i] = 0.5 * x * (1+tanh(sqrt(2/3.141592))) * x + 0.044715*x*x*x;
  }
}

void elewise_Hardswish_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    if(x<-3) dst_C_DRAM[i] = 0;
    else if(x>3) dst_C_DRAM[i] = x;
    else    dst_C_DRAM[i] = x*(x+3)/6;
  }
}

void elewise_LeakyReLU_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    if(x>0) dst_C_DRAM[i] = x;
    else    dst_C_DRAM[i] = 0.01*x;
  }
}

void elewise_tanh_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    dst_C_DRAM[i] = tanh(x);
  }
}

void elewise_hardsigmoid_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    if(x<-3) dst_C_DRAM[i] = 0;
    else if(x>3) dst_C_DRAM[i] = x;
    else    dst_C_DRAM[i] = x/6 + 1/2;
  }
}

void elewise_ELU_CPU(float *src_A_DRAM, float * dst_C_DRAM, int p_size, int q_size)
{
  for(size_t i=0;i<p_size*q_size;i++)
  {
    float x = (float)(src_A_DRAM[i]);
    if(x>0) dst_C_DRAM[i] = x;
    else    dst_C_DRAM[i] = 0.01*(exp(x)-1);
  }
}

int main(int argc, char *argv[])
{

    if(argc<4)
    {
        printf("Check vector param p,q,r (pxq) +-x (pxq) = (pxq)\n");
        printf("Bit precision 16(max) & Function type \n");
        printf("1: Div, 2: Sqrt, 3: Erf\n");
        exit(1);
    }
    
    int p_size = atoi(argv[1]);
    int q_size = atoi(argv[2]);
    int r_size = q_size;
    int bit_precision = 16; //MAX precision 16-bit 
    int cmd = atoi(argv[3]); //Function type
    // int memory_type = atoi(argv[4]); //Near or Far memory type

    // SrcA: Input X (p x q)
    // SrcB: LUT contents f (pow(2,bit_precision) x 2B)
    // DstC: f(x) (p x q)
    int srcA_size = p_size * q_size;
    int LUT_size = (1<<bit_precision);
    // int srcB_size = srcA_size;
    int dstC_size = p_size * q_size;

    int fd_dma=0;
    int fd_conf=0;

    init_pim_drv();
    if ((fd_dma=open(PL_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
        perror("PL DMA drvier open");
        exit(-1);
    }
    pim_args *set_info;
    int size = sizeof(pim_args);
    set_info = (pim_args *)malloc(1024*1024*size);

    short *PL_srcx_buf = (short *)pim_malloc(srcA_size*sizeof(short));
    short *PL_LUT_buf = (short *)pim_malloc(LUT_size*sizeof(short));
    // short *PL_srcLUT_buf = (short *)pim_malloc(srcB_size*sizeof(short));
    short *PL_fx_buf = (short *)pim_malloc(dstC_size*sizeof(short));

    if (PL_srcx_buf == MAP_FAILED) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (PL_LUT_buf == MAP_FAILED) {
        printf("PL LUT call failure.\n");
        return -1;
    }
    if (PL_fx_buf == MAP_FAILED) {
        printf("PL dstC call failure.\n");
        return -1;
    }

    //zeroing
    for(size_t i=0; i<srcA_size; i++){
      PL_srcx_buf[i]=0;
    }
    for(size_t i=0; i<LUT_size; i++){
      PL_LUT_buf[i]=0;
    }
    for(size_t i=0; i<dstC_size; i++){
      PL_fx_buf[i]=0;
    }

    float *src_A_DRAM;
    float *dst_C_DRAM;

    //For CPU verify
    // if(memory_type==0){
    src_A_DRAM = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    // dst_C_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    // }
    // else {
    // src_A_DRAM = (float* )pim_malloc(srcA_size*sizeof(float));
    // src_A_DRAM = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    dst_C_DRAM = (float* )pim_malloc(dstC_size*sizeof(float));
    // dst_C_DRAM = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    // }

    // Input data
    srand((unsigned int)time(NULL));  // For reset random seed
    
    // printf("src input(x) init\n");
    for(size_t i=0; i<srcA_size; i++){
      float tmp  = generate_random();
      // float tmp  = 0.5 + float(i);
      // float tmp  = 4.0;
      short tmp0 = float_to_short(tmp);
      PL_srcx_buf[i] = tmp0;
      src_A_DRAM[i] = short_to_float(tmp0);
    }
/*    
    std::ifstream lut_ptr;
    switch(cmd){
      case CMD_DIV:
          lut_ptr.open("./data/0.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }                
          break;
      case CMD_SQRT:
          lut_ptr.open("./data/1.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }
          break;
      case CMD_ERF:
          lut_ptr.open("./data/5.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }
          break;
      case CMD_EXP:
          lut_ptr.open("./data/2.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }
          break;
      case CMD_LOG:
          lut_ptr.open("./data/3.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }
          break;
      case CMD_POW:
          lut_ptr.open("./data/4.lut",std::ios::in|std::ios::binary);
          if (!lut_ptr) {
            printf("file can't be opened \n");
          }
          break;          
      default: 
          {
            printf("Unsupported Command\n");
            return -1;
          }
    }

    printf("src LUT contents(f) init\n");
    short *src_LUT_buf_temp = (short *)malloc(srcB_size*sizeof(short));
    if (src_LUT_buf_temp == MAP_FAILED) {
        printf("Layout::: Temporal allocation for LUT failed.\n");
        return -1;
    }
    int i = 0;
    float f;
    while (lut_ptr.read(reinterpret_cast<char*>(&f), sizeof(float))){
        // std::cout << f << '\n';
      float tmp  = f;
      short tmp0 = float_to_short(tmp);
      src_LUT_buf_temp[i]=tmp0;
      src_B_DRAM[i] = short_to_float(tmp0);
      i++;
    }   
*/

    float *src_LUT_layout = (float *)(mmap(NULL, LUT_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    int lut_row = 12; int lut_col = 4;
    int lut_ROW, lut_COL;
      lut_ROW = (1<<lut_row); lut_COL = (1<<lut_col);
    short input_addr;      
    float result;
    int v_addr=0; 

      for(size_t i=0; i<lut_ROW; i++){
          for(size_t k=0; k<lut_COL; k++){
            input_addr = i * lut_COL + k;
            switch(cmd){
              case CMD_DIV:   //1   
                  result = (float) (1/(short_to_float(input_addr)));   
                  break;
              case CMD_SQRT:  //2
                  result = (float) (sqrt((short_to_float(input_addr))));
                  break;
              case CMD_ERF:   //3
                  result = (float) (erf((short_to_float(input_addr))));
                  break;
              case CMD_EXP:   //4
                  result = (float) (exp((short_to_float(input_addr))));
                  break;
              case CMD_LOG:   //5
                  result = (float) (log((short_to_float(input_addr))));
                  break;
              case CMD_POW:
                  result = (float) (pow(2,(short_to_float(input_addr))));
                  break;
              // case CMD_SIN:
              //     result = (float) (sin(short_to_float(input_addr)));
              //     break;                       
              default: 
                  {
                    // printf("Unsupported Command for LUT table generation\n");
                    break;
                    // return -1;
                  }
            }
            src_LUT_layout [v_addr] = result;
            // std::cout<<"input  "<<std::hex<<input_addr<<"\t"; 
            // std::cout<<"16'h"<<std::hex<<float_to_short(result)<<std::endl;     
            PL_LUT_buf[v_addr] = float_to_short(src_LUT_layout[v_addr]);
            v_addr++;
          }
      }

    // printf("dst f(x) init\n");
    for(size_t i=0; i<dstC_size; i++){
      PL_fx_buf[i]=0;
      dst_C_DRAM[i] = 0;
    }

    
    clock_gettime(CLOCK_MONOTONIC, &start_CPU);
    switch(cmd){
      case CMD_DIV:
          // printf("Cpu Division\n");
          elewise_div_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_SQRT:
          // printf("Cpu Square Root\n");
          elewise_sqrt_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_ERF:
          // printf("Cpu Error Function\n");
          elewise_erf_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_EXP:
          // printf("Cpu Exponential\n");
          elewise_exp_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_LOG:
          // printf("Cpu Logarithm\n");
          elewise_log_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_POW:
          // printf("Cpu power(of 2)\n");
          elewise_pow_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;          
      case CMD_RELU:
          // printf("Cpu Sin\n");
          elewise_ReLU_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_SILU:
          // printf("Cpu Sin\n");
          elewise_SiLU_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_SIGMOID:
          // printf("Cpu Sin\n");
          elewise_sigmoid_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_GELU:
          // printf("Cpu Sin\n");
          elewise_GeLU_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_HARDSWISH:
          // printf("Cpu Sin\n");
          elewise_Hardswish_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_LRELU:
          // printf("Cpu Sin\n");
          elewise_LeakyReLU_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_TANH:
          // printf("Cpu Sin\n");
          elewise_tanh_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_HARDSIGMOID:
          // printf("Cpu Sin\n");
          elewise_hardsigmoid_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;
      case CMD_ELU:
          // printf("Cpu Sin\n");
          elewise_ELU_CPU(src_A_DRAM, dst_C_DRAM, p_size, q_size);
          break;          

      default: 
          {
            printf("Unsupported Command\n");
            return -1;
          }
    }
    clock_gettime(CLOCK_MONOTONIC, &end_CPU);  

    
    set_info->srcA_va   = (uint64_t)&PL_srcx_buf[0];
    set_info->srcB_va   = (uint64_t)&PL_LUT_buf[0];
    set_info->dstC_va   = (uint64_t)&PL_fx_buf[0];
    set_info->p_size    = p_size;
    set_info->q_size    = q_size;
    set_info->r_size    = r_size;
    
    set_info->lut_x_init = PL_srcx_buf[0];

    generate_indirect_lut_code(set_info);
    
    clock_gettime(CLOCK_MONOTONIC, &start_DMA);
    lut_op(set_info);
    // lut_search_all(set_info);
    clock_gettime(CLOCK_MONOTONIC, &end_DMA);

    diff_DMA = BILLION * (end_DMA.tv_sec - start_DMA.tv_sec) + (end_DMA.tv_nsec - start_DMA.tv_nsec);
    printf("PIM execution time %llu nanoseconds %d %d \n", (long long unsigned int) diff_DMA, p_size, q_size);
    diff_CPU = BILLION * (end_CPU.tv_sec - start_CPU.tv_sec) + (end_CPU.tv_nsec - start_CPU.tv_nsec);
    printf("CPU execution time %llu nanoseconds %d %d \n", (long long unsigned int) diff_CPU, p_size, q_size);
    

  // for (int i=0; i<srcA_size; i++){
  //   printf("PL_src[%d]=0x%x \n",i,PL_srcx_buf[i]);    
  // }


    union converter{
    float f_val;
    unsigned int u_val;
    };
    union converter a;
    union converter b;

    printf("Correctness check!\n\n");
    printf("       HOST           |  PIM\n");
    for(int i=0; i<dstC_size; i++){
        a.f_val = dst_C_DRAM[i];
        // printf("input[%4d]=%f\n", i, src_A_DRAM[i]);
        printf("idx[%4d] 0x%x  |  ", i, a.u_val);
        printf("0x%x ", PL_fx_buf[i]);
        printf("\n");
        // if (i == 32) // Only Bank 0
        //     break;        
    }
    printf("\n");

    return 0;
}




