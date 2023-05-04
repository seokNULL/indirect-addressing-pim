#include <sys/mman.h>
#include <stddef.h>
#include <stdio.h>
#include <assert.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <stdbool.h>
#include "pim_math.h"


uint64_t desc_base = 0x0;
uint64_t dram_base = 0x0;
static int dma_fd = 0;
pim_isa_t *pim_isa;

void close_pim_drv(void) {
	if (dma_fd != 0) {
		close(dma_fd);
		dma_fd = 0;
        free(pim_isa);
	}	
}

int init_pim_drv(void) {
    if (dma_fd == 0) {
        pim_isa = (pim_isa_t *)malloc(sizeof(pim_isa_t) * 2048); /* 2048 is temporal maximum descriptor */
        dma_fd = open(PL_DMA_DRV, O_RDWR, 0);
        if (dma_fd < 0) {
            printf("\033[0;31m Couldn't open device: %s (%d) \033[0m\n", PL_DMA_DRV, dma_fd);
            return -1;
        }
        pim_args pim_args;
        ioctl(dma_fd, DESC_MEM_INFO, &pim_args);
        desc_base = pim_args.desc_base;
        dram_base = pim_args.dram_base;
        PIM_MATH_LOG("%s: desc_base: %lx, dram_base: %lx \n", __func__, desc_base, dram_base);
    	atexit(close_pim_drv);
    }
    return 0;
}

uint64_t VA2PA(uint64_t va) {
    pim_args pim_args;
    pim_args.va = va;
    if (dma_fd != 0) {    
		ioctl(dma_fd, VA_TO_PA, &pim_args);
#ifdef __x86_64__
        /* In X86, PL memory address MUST BE changed (Refer. Vivado) */
		return pim_args.pa - 0x60000000;
#elif defined __aarch64__
        return pim_args.pa;
#endif
	} else {
		printf("\033[0;31m DMA driver not loaded! \033[0m");
		assert(0);
	}
}

int pim_exec(pim_args *pim_args) {
    if (dma_fd != 0) {
        pim_args->desc_host = pim_isa;
    	PIM_MATH_LOG("%s: desc_host:%p, num_desc:%d, last_desc:%x \n", 
    		__func__, pim_args->desc_host, pim_args->desc_idx, pim_args->desc_last);
		if (ioctl(dma_fd, DMA_START, pim_args) < 0) {
            printf("\033[0;31m DMA transaction failed! \033[0m\n");
			return -1;
        }
		return 0;
	} else {
		printf("\033[0;31m DMA driver not loaded! \033[0m");
		return -1;
	}
}