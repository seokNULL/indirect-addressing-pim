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

#define va_to_pa(va) syscall(333, va)
#define MAP_PCIE 0x40
#define NPAGES 0x200000
#define ITERATION 1
void clflush(void *a) {
    //__asm volatile("clflush (%0)"
    //               :
    //               : "r" (a)
    //               : "memory");
}


int main(int argc, char *argv[])
{
    if (argc < 4) {
        printf("Usage: \n");
        printf("./dmat_test MODE p, q \n\n");
        printf("            MODE 0:  MEMCPY   (No DMA) \n");
        printf("            MODE 1:  HOST DMA (HOST <-> HOST) \n");
        printf("            MODE 2:  HOST DMA (HOST <-> HOST zero-copy) \n");
        printf("            MODE 3:  HOST DMA (HOST <-> FPGA) \n");
        printf("            MODE 4:  HOST DMA (FPGA <-> HOST) \n");
        //printf("            MODE 4:  HOST DMA (FPGA <-> FPGA) \n");
        exit(1);
    }
    int mode =   atoi (argv[1]);
    int bytes_len = (atoi (argv[2])) * 1024;

    int src_ele = bytes_len / sizeof(Bfloat16);
    struct timespec start_t, end_t;
    volatile unsigned long long diff_t=0;
    volatile unsigned long long total_exe=0;
    volatile unsigned long long iteration=ITERATION;
    int fd=0;
    //printf("Size: %d KB\n", bytes_len);
    if (mode == 0) {
        printf("MEMCPY (No DMA)\n");
        Bfloat16 *src_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        Bfloat16 *tmp_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        for (int i = 0; i < src_ele; i++) {
            tmp_buff[i] = 0;
            src_buff[i] = i % 100;
        }        
        register int j;
        for (j = 0; j < iteration; j++) {
            for (int i = 0; i < src_ele; i++) {
                clflush(&src_buff[i]);
            }
            clock_gettime(CLOCK_MONOTONIC, &start_t);
            memcpy(tmp_buff, src_buff, bytes_len);
            clock_gettime(CLOCK_MONOTONIC, &end_t);

            diff_t = 1000000000 * (end_t.tv_sec - start_t.tv_sec) + (end_t.tv_nsec - start_t.tv_nsec);
            total_exe += diff_t;
        }
        bool error_=false;
        for (size_t i = 0; i < src_ele; ++i) {
            if (tmp_buff[i] != src_buff[i]) {
                error_=true;
            }
        }        
        printf("\n Average Elapsed time: %llu \n\n", total_exe/iteration);
        if (error_) {
            printf("Correctness check failed \n");
        }
    } else if (mode == 1) {

        int p_size = atoi(argv[1]);
        int q_size = atoi(argv[2]);
        int r_size = q_size;
        int srcA_size = p_size * q_size;
        int srcB_size = p_size * q_size;
        int dstC_size = p_size * q_size;
        int tmp=0;
        uint64_t dummy_buf_PA;
        bool success = true;

        pim_args *set_info;
        int size = sizeof(pim_args);
        set_info = (pim_args *)malloc(size);

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
        getchar();
        //zeroing

        for(size_t i=0; i<srcA_size; i++){
          PL_srcA_buf[i]=0;
        }
        for(size_t i=0; i<dstC_size; i++){
          PL_dstC_buf[i]=0;
        }

        printf("Complete zeroing PL memory \n");
        getchar();
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
        getchar();
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


        printf("MEMCPY (HOST to HOST)\n");
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

        //clock_gettime(CLOCK_MONOTONIC, &start_PL2PS);

        //__cache_flush(PS_dstC_buf, dstC_size*sizeof(short));
        
        if (ioctl(fd_dma, MEMCPY_PL2PS, set_info) < 0) {
            printf("ERROR DMA \n");
            return 0;
        }
        //clock_gettime(CLOCK_MONOTONIC, &end_PL2PS);

        //diff_PL2PS = BILLION * (end_PL2PS.tv_sec - start_PL2PS.tv_sec) + (end_PL2PS.tv_nsec - start_PL2PS.tv_nsec);
        //printf("MEM_CPY PL --> PS execution time %llu nanoseconds %d %d\n", (long long unsigned int) diff_PL2PS, p_size, q_size);

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

    } else if (mode == 2) {
        printf("MEMCPY (HOST to HOST zero-copy)\n");

        if ((fd=open(X86_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
            perror("open");
            exit(-1);
        }
        Bfloat16 *src_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_LOCKED, fd, 0);
        Bfloat16 *dst_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_LOCKED, fd, 0);

        if ((src_buff == MAP_FAILED) || (dst_buff == MAP_FAILED)) {
            perror("dma_sg mmap ");
            exit(-1);
        }    
        for (size_t i = 0; i < src_ele; ++i) {
            src_buff[i] = i % 100;
            dst_buff[i] = 0;
        }
        pim_args *set_info;
        int size = sizeof(pim_args);
        set_info = (pim_args *)malloc(size);
        set_info->length=bytes_len;
        set_info->srcA_ptr = src_buff;
        set_info->dstC_ptr = dst_buff;
        register int j;
        for (j = 0; j < iteration; j++) {
            clock_gettime(CLOCK_MONOTONIC, &start_t);
            ioctl(fd, H2H_ZCPY, set_info);
            clock_gettime(CLOCK_MONOTONIC, &end_t);

            diff_t = 1000000000 * (end_t.tv_sec - start_t.tv_sec) + (end_t.tv_nsec - start_t.tv_nsec);
            total_exe += diff_t;
        }
        bool error_=false;
        size_t i;
        for (i = 0; i < src_ele; ++i) {
            if ((src_buff[i] != (i%100)) || (src_buff[i] != dst_buff[i])) {
                error_=true;
                break;                
            }
        }
        printf("\n Average Elapsed time: %llu \n\n", total_exe/iteration);
        if (error_) {
            printf("Correctness check failed (idx:%lu) \n", i);
        }

    } else if (mode == 3) {
        printf("MEMCPY (HOST to FPGA)\n");

        if ((fd=open(X86_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
            perror("open");
            exit(-1);
        }
        Bfloat16 *src_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_READ|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        Bfloat16 *dst_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE, -1, 0);

        if ((src_buff == MAP_FAILED) || (dst_buff == MAP_FAILED)) {
            perror("dma_sg mmap ");
            exit(-1);
        }    
        for (size_t i = 0; i < src_ele; ++i) {
            src_buff[i] = i % 100;
            dst_buff[i] = 0;
        }
        pim_args *set_info;
        int size = sizeof(pim_args);
        set_info = (pim_args *)malloc(size);
        set_info->length=bytes_len;
        set_info->srcA_ptr = src_buff;
        set_info->dstC_ptr = dst_buff;
        register int j;
        for (j = 0; j < iteration; j++) {
            clock_gettime(CLOCK_MONOTONIC, &start_t);
            ioctl(fd, HOST2FPGA, set_info);
            clock_gettime(CLOCK_MONOTONIC, &end_t);

            diff_t = 1000000000 * (end_t.tv_sec - start_t.tv_sec) + (end_t.tv_nsec - start_t.tv_nsec);
            total_exe += diff_t;
        }
        bool error_=false;
        for (size_t i = 0; i < src_ele; ++i) {
            if ((src_buff[i] != (i%100)) || (src_buff[i] != dst_buff[i])) {
                error_=true;
                break;
            }
        }
        printf("\n Average Elapsed time: %llu \n\n", total_exe/iteration);
        if (error_) {
            printf("Correctness check failed \n");
        }
    } else if (mode == 4) {
         printf("MEMCPY (FPGA to HOST)\n");

        if ((fd=open(X86_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
            perror("open");
            exit(-1);
        }

        Bfloat16 *src_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS | MAP_PCIE, -1, 0);
        Bfloat16 *dst_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_READ|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

        if ((src_buff == MAP_FAILED) || (dst_buff == MAP_FAILED)) {
            perror("dma_sg mmap ");
            exit(-1);
        }    
        for (size_t i = 0; i < src_ele; ++i) {
            src_buff[i] = i % 100;
            dst_buff[i] = 0;
        }
        pim_args *set_info;
        int size = sizeof(pim_args);
        set_info = (pim_args *)malloc(size);
        set_info->length=bytes_len;
        set_info->srcA_va = va_to_pa(&(((Bfloat16 *)(src_buff))[0]));
        set_info->srcA_ptr = src_buff;
        set_info->dstC_ptr = dst_buff;
        register int j;

        for (j = 0; j < iteration; j++) {
            /* Cache flush performed in DMA driver using dma_cache_sync */
            //for (int i = 0; i < src_ele; i++) {
            //    //clflush(&src_buff[i]);
            //    //clflush(&dst_buff[i]);
            //}
            clock_gettime(CLOCK_MONOTONIC, &start_t);
            ioctl(fd, FPGA2HOST, set_info);
            clock_gettime(CLOCK_MONOTONIC, &end_t);

            diff_t = 1000000000 * (end_t.tv_sec - start_t.tv_sec) + (end_t.tv_nsec - start_t.tv_nsec);
            total_exe += diff_t;
        }
        bool error_=false;
        for (size_t i = 0; i < src_ele; ++i) {
            if ((src_buff[i] != (i%100)) || (src_buff[i] != dst_buff[i])) {
                error_=true;
                break;
            }
        }
        printf("\n Average Elapsed time: %llu \n\n", total_exe/iteration);
        if (error_) {
            printf("Correctness check failed \n");
        }
    } else {
        printf("Mode is 0-5 \n");
        exit(1);
    }
 
    return 0;
}
