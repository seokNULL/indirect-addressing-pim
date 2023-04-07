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


struct timespec start_PL2PS, end_PL2PS;
struct timespec start_PS2PL, end_PS2PL;
struct timespec start_PL2PL, end_PL2PL;

struct timespec start_PL2PS_MEMCPY, end_PL2PS_MEMCPY;
struct timespec start_PS2PL_MEMCPY, end_PS2PL_MEMCPY;
struct timespec start_PL2PL_MEMCPY, end_PL2PL_MEMCPY;

uint64_t diff_PL2PS;
uint64_t diff_PS2PL;
uint64_t diff_PL2PL;


uint64_t diff_PL2PS_MEMCPY;
uint64_t diff_PS2PL_MEMCPY;
uint64_t diff_PL2PL_MEMCPY;

int iter;

int main(int argc, char *argv[])
{

    if(argc<4) {
        printf("Check vector size param p,q (pxq)\n");
        printf("./memcpy p q MODE (0, 1, 2)\n");
        printf("             MODE 0: FPGA to FPGA \n");
        printf("             MODE 1: FPGA to Host \n");
        printf("             MODE 2: Host to FPGA \n");
        exit(1);
    }
    
    int p_size = atoi(argv[1]);
    int q_size = atoi(argv[2]);
    int r_size = q_size;

    int cmd = atoi(argv[3]);

    int srcA_size = p_size * q_size;
    int srcB_size = p_size * q_size;
    int dstC_size = p_size * q_size;

    int tmp=0;

    int fd_dma=0;
    init_pim_drv();
    if ((fd_dma=open(PL_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
        perror("PL DMA drvier open");
        exit(-1);
    }
    printf("Memory copy size: %lu B\n", p_size * q_size * sizeof(short));
    short *PL_srcA_buf = (short *)pim_malloc(srcA_size*sizeof(short));
    short *PL_dstC_buf = (short *)pim_malloc(dstC_size*sizeof(short));

    if (PL_srcA_buf == MAP_FAILED) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (PL_dstC_buf == MAP_FAILED) {
        printf("PL dstC call failure.\n");
        return -1;
    }
    printf("Complete pim_malloc\n");
    uint64_t A_pa = VA2PA((uint64_t)&PL_srcA_buf[0]);    
    uint64_t B_pa = VA2PA((uint64_t)&PL_dstC_buf[0]);    
    printf("A:%llx \n", A_pa);
    printf("B:%llx \n", B_pa);
    // getchar();
    //zeroing

    for(size_t i=0; i<srcA_size; i++){
      PL_srcA_buf[i]=0;
    }
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i]=0;
    }

    printf("Complete zeroing PL memory \n");
    // getchar();
    //For CPU verify
    short *PS_srcA_buf = (short *)(mmap(NULL, srcA_size*sizeof(short), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    short *PS_dstC_buf = (short *)(mmap(NULL, dstC_size*sizeof(short), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    printf("PL_srcA_buf %p\n", PL_srcA_buf);
    printf("PL_dstC_buf %p\n", PL_dstC_buf);
    printf("PS_srcA_buf %p\n", PS_srcA_buf);
    printf("PS_dstC_buf %p\n", PS_dstC_buf);

    if (PS_srcA_buf == MAP_FAILED) {
        printf("PS srcA call failure.\n");
        return -1;
    }
    if (PS_dstC_buf == MAP_FAILED) {
        printf("PS dstC call failure.\n");
        return -1;
    }
    printf("Complete ps malloc \n");
    // getchar();
    for(size_t i=0; i<srcA_size; i++){
      PS_srcA_buf[i]=0;
    }
    for(size_t i=0; i<dstC_size; i++){
      PS_dstC_buf[i]=0;
    }
    // Input data
    srand((unsigned int)time(NULL));  // For reset random seed
    
    printf("srcA init\n");
    for(size_t i=0; i<srcA_size; i++){
      float tmp  = generate_random();
      short tmp0 = float_to_short(tmp);
      PL_srcA_buf[i] = tmp0;
      PS_srcA_buf[i] = tmp0;
    }  


    printf("dstC init\n");
    for(size_t i=0; i<dstC_size; i++){
      PL_dstC_buf[i] =0;
      PS_dstC_buf[i] = 0;
    }

    void *srcA;
    void *srcB;
    void *dstC;

    uint64_t srcA_va;
    uint64_t srcB_va;
    uint64_t dstC_va;

    uint64_t dummy_buf_PA;
    bool success = true;
    
    printf("Enter to start DMA transaction");
    getchar();
    

    pim_args *set_info;
    int size = sizeof(pim_args);
    set_info = (pim_args *)malloc(size);

    if(cmd==0){
        set_info->srcA_ptr  = PL_srcA_buf;
        set_info->srcB_ptr  = NULL;
        set_info->dstC_ptr  = PL_dstC_buf;    
        set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0];
        set_info->srcB_va   = 0x0;
        set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0];
        set_info->srcA_size = srcA_size*sizeof(short);
        set_info->srcB_size = 0x0;
        set_info->dstC_size = dstC_size*sizeof(short);
        set_info->p_size    = 0x0;
        set_info->q_size    = 0x0;
        set_info->r_size    = 0x0;
        clock_gettime(CLOCK_MONOTONIC, &start_PL2PL);
        
        if (ioctl(fd_dma, MEMCPY_PL2PL, set_info) < 0) {
            printf("ERROR DMA \n");
            return 0;
        }
        clock_gettime(CLOCK_MONOTONIC, &end_PL2PL);

        diff_PL2PL = BILLION * (end_PL2PL.tv_sec - start_PL2PL.tv_sec) + (end_PL2PL.tv_nsec - start_PL2PL.tv_nsec);
        printf("MEM_CPY PL --> PL execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PL2PL, p_size, q_size);

        printf("Correctness PL --> PL check!\n\n");
        for(int i=0; i<dstC_size; i++){ 
            if(PL_srcA_buf[i] != PL_dstC_buf[i]) {
                printf("Error PL_src[%d]=%d PS_dst[%d]=%d \n",i,PL_srcA_buf[i],i,PS_dstC_buf[i]);
                success = false;
                break;
            }
        }
        if (!success)
            printf("Correctness PL --> PL check failed!\n\n");
        else
            printf("Correctness PL --> PL check done!\n\n");
    } else if(cmd==1){
        set_info->srcA_ptr  = PL_srcA_buf;
        set_info->srcB_ptr  = NULL;
        set_info->dstC_ptr  = PS_dstC_buf;    
        set_info->srcA_va   = (uint64_t)&PL_srcA_buf[0];
        set_info->srcB_va   = 0x0;
        set_info->dstC_va   = (uint64_t)&PS_dstC_buf[0];
        set_info->srcA_size = srcA_size*sizeof(short);
        set_info->srcB_size = 0x0;
        set_info->dstC_size = dstC_size*sizeof(short);
        set_info->p_size    = 0x0;
        set_info->q_size    = 0x0;
        set_info->r_size    = 0x0;
        // set_info->dummy_buf_PA = NULL;

        clock_gettime(CLOCK_MONOTONIC, &start_PL2PS);

        //__cache_flush(PS_dstC_buf, dstC_size*sizeof(short));
        
        if (ioctl(fd_dma, MEMCPY_PL2PS, set_info) < 0) {
            printf("ERROR DMA \n");
            return 0;
        }
        clock_gettime(CLOCK_MONOTONIC, &end_PL2PS);

        diff_PL2PS = BILLION * (end_PL2PS.tv_sec - start_PL2PS.tv_sec) + (end_PL2PS.tv_nsec - start_PL2PS.tv_nsec);
        printf("MEM_CPY PL --> PS execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PL2PS, p_size, q_size);

        printf("Correctness PL --> PS check!\n\n");
        for(int i=0; i<dstC_size; i++){ 
            if(PL_srcA_buf[i] != PS_dstC_buf[i]) {
                printf("Error PL_src[%d]=%d PS_dst[%d]=%d \n",i,PL_srcA_buf[i],i,PS_dstC_buf[i]);
                success = false;
                break;
            }
            //printf("Error PL_src[%d]=%d PS_dst[%d]=%d \n",i,PL_srcA_buf[i],i,PS_dstC_buf[i]);
        }
        if (!success)
            printf("Correctness PL --> PS check failed!\n\n");
        else
            printf("Correctness PL --> PS check done!\n\n");
    }
    else if(cmd==2){
        set_info->srcA_ptr  = PS_srcA_buf;
        set_info->srcB_ptr  = NULL;
        set_info->dstC_ptr  = PL_dstC_buf;    
        set_info->srcA_va   = (uint64_t)&PS_srcA_buf[0];
        set_info->srcB_va   = 0x0;
        set_info->dstC_va   = (uint64_t)&PL_dstC_buf[0];
        set_info->srcA_size = srcA_size*sizeof(short);
        set_info->srcB_size = 0x0;
        set_info->dstC_size = dstC_size*sizeof(short);
        set_info->p_size    = 0x0;
        set_info->q_size    = 0x0;
        set_info->r_size    = 0x0;
        // set_info->dummy_buf_PA = NULL;

        clock_gettime(CLOCK_MONOTONIC, &start_PS2PL);

        //__cache_flush(PS_srcA_buf, srcA_size*sizeof(short));

        if (ioctl(fd_dma, MEMCPY_PS2PL, set_info) < 0) {
            printf("ERROR DMA \n");
            return 0;
        }
        clock_gettime(CLOCK_MONOTONIC, &end_PS2PL);

        diff_PS2PL = BILLION * (end_PS2PL.tv_sec - start_PS2PL.tv_sec) + (end_PS2PL.tv_nsec - start_PS2PL.tv_nsec);
        printf("MEM_CPY PS --> PL execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PS2PL, p_size, q_size);

        printf("Correctness PS --> PL check!\n\n");
        for(int i=0; i<dstC_size; i++){ 
            if(PS_srcA_buf[i] != PL_dstC_buf[i]) {
                printf("Error PS_src[%d]=%d PL_dst[%d]=%d \n",i,PS_srcA_buf[i],i,PL_dstC_buf[i]);
                success = false;
                break;
            }
            //printf("Error PS_src[%d]=%d PL_dst[%d]=%d \n",i,PS_srcA_buf[i],i,PL_dstC_buf[i]);
        }
        if (!success)
            printf("Correctness PS --> PL check failed!\n\n");
        else
            printf("Correctness PS --> PL check done!\n\n");
    }
    else if(cmd==3){
        clock_gettime(CLOCK_MONOTONIC, &start_PL2PS_MEMCPY);

        memcpy(PS_dstC_buf, PL_srcA_buf, srcA_size*sizeof(short));

        clock_gettime(CLOCK_MONOTONIC, &end_PL2PS_MEMCPY);

        diff_PL2PS_MEMCPY = BILLION * (end_PL2PS_MEMCPY.tv_sec - start_PL2PS_MEMCPY.tv_sec) + (end_PL2PS_MEMCPY.tv_nsec - start_PL2PS_MEMCPY.tv_nsec);
        printf("MEM_CPY FUNC PL --> PS execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PL2PS_MEMCPY, p_size, q_size);

        printf("Correctness PL --> PS check!\n\n");
        for(int i=0; i<dstC_size; i++){ 
            if(PL_srcA_buf[i] != PS_dstC_buf[i]) {
                printf("Error PL_src[%d]=%d PS_dst[%d]=%d \n",i,PL_srcA_buf[i],i,PS_dstC_buf[i]);
                success = false;
                break;
            }
            //printf("Error PL_src[%d]=%d PS_dst[%d]=%d \n",i,PL_srcA_buf[i],i,PS_dstC_buf[i]);
        }
        if (!success)
            printf("Correctness PL --> PS check failed!\n\n");
        else
            printf("Correctness PL --> PS check done!\n\n");        
    }
    else if(cmd==4){
        clock_gettime(CLOCK_MONOTONIC, &start_PS2PL_MEMCPY);

        memcpy(PL_dstC_buf, PS_srcA_buf, srcA_size*sizeof(short));

        clock_gettime(CLOCK_MONOTONIC, &end_PS2PL_MEMCPY);

        diff_PS2PL_MEMCPY = BILLION * (end_PS2PL_MEMCPY.tv_sec - start_PS2PL_MEMCPY.tv_sec) + (end_PS2PL_MEMCPY.tv_nsec - start_PS2PL_MEMCPY.tv_nsec);
        printf("MEM_CPY FUNC PS --> PL execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PS2PL_MEMCPY, p_size, q_size);

        printf("Correctness PS --> PL check!\n\n");
        for(int i=0; i<dstC_size; i++){ 
            if(PS_srcA_buf[i] != PL_dstC_buf[i]) {
                printf("Error PS_src[%d]=%d PL_dst[%d]=%d \n",i,PS_srcA_buf[i],i,PL_dstC_buf[i]);
                success = false;
                break;
            }
            //printf("Error PS_src[%d]=%d PL_dst[%d]=%d \n",i,PS_srcA_buf[i],i,PL_dstC_buf[i]);
        }
        if (!success)
            printf("Correctness PS --> PL check failed!\n\n");
        else
            printf("Correctness PS --> PL check done!\n\n");
    }
    else{
        printf("CMD ERROR!\n");
    }
    return 0;
}





