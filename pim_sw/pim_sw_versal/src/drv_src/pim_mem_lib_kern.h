#ifndef _PIM_MEM_KERN_LIB_
#define _PIM_MEM_KERN_LIB_

#include <linux/module.h>


extern volatile uint32_t *pim_mem_reg;

//#define PIM_MEM_DEBUG
#define RESERVED 0x1000000

#ifdef __x86_64__
extern int probe_pim_mem_x86(void);
#elif defined __aarch64__
extern int probe_pim_mem_arm(struct platform_device *pdev);
#endif

extern void remove_pim_mem(void);
extern int register_pim_mem(void);

//extern u64 va_to_pa(u64 vaddr);

#endif // _PIM_KERNEL_LIB_
