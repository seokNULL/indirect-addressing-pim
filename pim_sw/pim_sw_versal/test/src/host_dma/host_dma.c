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

#include <time.h>
#define va_to_pa(va) syscall(333, va)
#define MAP_PCIE 0x40
#define NPAGES 0x200000
#define ITERATION 1
void clflush(void *a) {
    __asm volatile("clflush (%0)"
                   :
                   : "r" (a)
                   : "memory");
}


int main(int argc, char *argv[])
{
    if (argc < 3) {
        printf("Usage: \n");
        printf("./dmat_test MODE N-byte \n\n");
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
    printf("Size: %d KB\n", bytes_len);
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
        printf("MEMCPY (HOST to HOST)\n");

        if ((fd=open(X86_DMA_DRV, O_RDWR|O_SYNC)) < 0) {
            perror("open");
            exit(-1);
        }
        Bfloat16 *src_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_READ|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        Bfloat16 *dst_buff = (Bfloat16 *)mmap(0x0, bytes_len, PROT_WRITE|PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

        if ((src_buff == MAP_FAILED) || (dst_buff == MAP_FAILED)) {
            perror("dma_sg mmap ");
            exit(-1);
        }    
        for (size_t i = 0; i < src_ele; ++i) {
            src_buff[i] = i % 100;
            dst_buff[i] = 0;
        }
        ioctl_info *set_info;
        int size = sizeof(ioctl_info);
        set_info = (ioctl_info *)malloc(size);
        set_info->length=bytes_len;
        set_info->srcA_ptr = src_buff;
        set_info->dstC_ptr = dst_buff;
        register int j;
        for (j = 0; j < iteration; j++) {
            clock_gettime(CLOCK_MONOTONIC, &start_t);
            ioctl(fd, HOST2HOST, set_info);
            clock_gettime(CLOCK_MONOTONIC, &end_t);

            diff_t = 1000000000 * (end_t.tv_sec - start_t.tv_sec) + (end_t.tv_nsec - start_t.tv_nsec);
            total_exe += diff_t;
        }
        bool error_=false;
        for (size_t i = 0; i < src_ele; ++i) {
            if ((src_buff[i] != (i%100)) || (src_buff[i] != dst_buff[i])) {
                error_=true;
            }
        }
        printf("\n Average Elapsed time: %llu \n\n", total_exe/iteration);
        if (error_) {
            printf("Correctness check failed \n");
        }
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
        ioctl_info *set_info;
        int size = sizeof(ioctl_info);
        set_info = (ioctl_info *)malloc(size);
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
        ioctl_info *set_info;
        int size = sizeof(ioctl_info);
        set_info = (ioctl_info *)malloc(size);
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
        ioctl_info *set_info;
        int size = sizeof(ioctl_info);
        set_info = (ioctl_info *)malloc(size);
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
