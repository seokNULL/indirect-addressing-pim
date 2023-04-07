#ifndef _PIM_MEM_LIB_
#define _PIM_MEM_LIB_

#ifdef __aarch64__
/* Sync system-user.dtsi */
#define PIM_MEM_PLATFORM "pim-mem-region"
#endif

#define PIM_MEM_NAME "pim_mem"

#define PIM_MEM_DEV "/dev/pim_mem"
#define DRAM_OFFSET     0x80000000 /* For a case where the PCIe BAR address is greater than 0x80000000 in x86 (Athena server) */
#define CONF_REG_OFFSET 0x0
#define CONF_REG_LEN    0x200000

#define HUGE_PAGE_SIZE 0x200000 /* 2MB */

#define PIM_MEM_INFO 0

typedef struct {
	uint64_t size;
	uint64_t addr;
}  __attribute__ ((packed)) pim_mem_info;

#endif // _PIM_MEM_LIB_
