#include "pim_mem.h"


static uint64_t pim_mem_size = 0;
static void *pim_mem = NULL;

#ifdef __FPGA__
static int pim_mem_fd = 0;
static uint64_t total_size = 0;
#endif

void *mmap_drv(int size)
{
#ifdef __FPGA__	
    void *ptr = pim_mem+total_size;

    total_size = total_size + size;
    if (total_size > pim_mem_size) {
    	printf("PIM] OOM \n");
 		assert(0);
    }
#else    
    void *ptr = mmap(0x0, size, (PROT_READ | PROT_WRITE), MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
#endif    
    PIM_MEM_LOG("MMAP - ptr:%p (Size: %d) \n", ptr, size);
    return ptr;
}

void __init_pim_drv(void) {
    atexit(__release_pim_drv);
#ifdef __FPGA__
    pim_mem_fd = open(PIM_MEM_DEV, O_RDWR, 0);
    if (pim_mem_fd < 0) {
        printf("couldn't open device: %s (%d) \n", PIM_MEM_DEV, pim_mem_fd);
        assert(0);
    }
    pim_mem_info pim_info;
    pim_info.addr = 0;
    pim_info.size = 0;
    ioctl(pim_mem_fd, PIM_MEM_INFO, &pim_info);
    if ((pim_info.addr == 0) || (pim_info.size == 0)) {
    	printf("Error PIM driver\n");
    	assert(0);
    }
    PIM_MEM_LOG("INIT PIM drv (PID: %d)\n", getpid());
	PIM_MEM_LOG("PIM memory addr: %lx\n", pim_info.addr);
	PIM_MEM_LOG("PIM memory size: %lx\n", pim_info.size);
    pim_mem_size = pim_info.size;
    pim_mem = mmap(0, pim_info.size, PROT_READ | PROT_WRITE, MAP_SHARED, pim_mem_fd, pim_info.addr);
#else
    pim_mem_info pim_info;
    pim_info.addr = 0;
    pim_info.size = 0x3f000000;  // 1GB - 16MB
    pim_mem_size = pim_info.size;    
	pim_mem = mmap(0x0, pim_mem_size, (PROT_READ | PROT_WRITE), MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
#endif
}

void __release_pim_drv(void) {
#ifdef __FPGA__	
	PIM_MEM_LOG("Release PIM driver (PID: %d) \n", getpid());
	if (pim_mem_fd > 0) {
		close(pim_mem_fd);
		pim_mem_fd = -1;
		PIM_MEM_LOG("\t Close PIM driver \n");
	}
	if (pim_mem != NULL) {
		munmap(pim_mem, pim_mem_size);
		pim_mem = NULL;
		PIM_MEM_LOG("\t Unmap PIM memory \n");
	}
#else
	if (pim_mem != NULL) {
		munmap(pim_mem, pim_mem_size);
		pim_mem = NULL;
		PIM_MEM_LOG("\t Unmap PIM memory (System DRAM) \n");
	}	
#endif
}
