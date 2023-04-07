#include <linux/init.h>
#include <linux/module.h>
#include <linux/if_arp.h>
#include <linux/interrupt.h>
#include <linux/sched.h>
#include <linux/kref.h>
#include <linux/pci.h>
#include <linux/smp.h>
#include <asm/pgtable.h>
#include <asm/tlbflush.h>
#include <linux/kallsyms.h>
#include <linux/mmzone.h>
#include <linux/uaccess.h>
#ifdef __x86_64__
//#include <asm/pat.h>
#include <asm/set_memory.h>
#endif
#include <asm/page.h>

#include <linux/mm.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/kernel.h>

#include <linux/module.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/delay.h>

#include <asm/io.h>
#include <asm/uaccess.h>
#include <linux/kernel.h>
#include <linux/ioport.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/version.h>


#include <linux/mutex.h>
#include <linux/version.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/mm.h>
#include <linux/dma-mapping.h>
#ifdef MODVERSIONS
#  include <linux/modversions.h>
#endif
#include <asm/io.h>
#include <linux/pci.h>

#include <linux/async_tx.h>
#include <linux/async.h>
#include <linux/uaccess.h>
#include <linux/kernel.h>
#include <linux/highmem.h>
#include <linux/delay.h>
#include <linux/spinlock.h>


#ifdef __aarch64__
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_device.h>
#endif

#include "../../include/pim.h"
#include "dma_lib_kern.h"
#include "pim_mem_lib_user.h"
#include "pim_mem_lib_kern.h"

u64 va_to_pa(u64 vaddr)
{
    pgd_t *pgd;
    pud_t *pud;
    pmd_t *pmd;
    pte_t *pte;
    unsigned long paddr = 0;
    unsigned long page_addr = 0;
    unsigned long page_offset = 0;
    struct mm_struct *mm = current->mm;
    struct vm_area_struct *vma_t = find_vma(current->mm, vaddr);

    /* Page table walk */    
    pgd = pgd_offset(mm, vaddr);
    if (pgd_none(*pgd)) {
        printk("not mapped in pgd %llx\n", vaddr);
        return -1;
    }
    pud = pud_offset((p4d_t *)pgd, vaddr);
    if (pud_none(*pud)) {
        printk("not mapped in pud %llx\n", vaddr);
        return -1;
    }
    pmd = pmd_offset(pud, vaddr);
    if (pmd_none(*pmd)) {
        printk("not mapped in pmd %llx\n", vaddr);
        pmd = pmd_offset(pud, vaddr);
        if (pmd_none(*pmd)){
            printk("Error-Not mapped in pmd %llx\n", vaddr);
            return -1;
        }
    }
    pte = pte_offset_kernel(pmd, vaddr);
    // For result mmap region (No touched region)
    if (pte_none(*pte)) {
        printk("Error-Not mapped in PTE (%lx) %llx\n",vma_t->vm_flags, vaddr);
        return -1;
    }
    /* Page frame physical address mechanism | offset */
    page_addr = pte_val(*pte) & PAGE_MASK;
    page_offset = vaddr & ~PAGE_MASK;
    paddr = page_addr | page_offset;
    return paddr;
}

#ifdef __x86_64__
int pim_drv_init_x86(void)
{
    int ret = 0;

    ret = probe_pim_mem_x86();
    if (ret < 0) {
        printk(KERN_ERR "PIM_MEM] Probing PIM-MEM failed (Error code: %d)", ret);
    } else {
        ret = register_pim_mem();
        if (ret < 0) {
            printk(KERN_ERR "PIM_MEM] Failed to register PIM-MEM device (Error code: %d)", ret);
        } else {
            printk("PIM_MEM] PIM-MEM driver Probe success");
            printk("PIM_MEM] ----------------------------");
        }
    }
    ret = probe_pl_dma_x86();
    if (ret < 0) {
        printk(KERN_ERR " PL_DMA] Probing PL-DMA failed (Error code: %d)", ret);
    } else {
        ret = register_pl_drv();
        if (ret < 0) {
            printk(KERN_ERR " PL_DMA] Failed to register PL-DMA device (Error code: %d)", ret);
        } else {
            printk(" PL_DMA] PL-DMA driver Probe success");
            printk(" PL_DMA] ---------------------------");            
        }
    }
    ret = probe_host_dma();
    if (ret < 0) {
        printk(KERN_ERR "x86_DMA] Probing x86-DMA failed (Error code: %d)", ret);      
    } else {
        ret = register_host_drv();
        if (ret < 0) {
            printk(KERN_ERR "x86_DMA] Failed to register x86-DMA device (Error code: %d)", ret);            
        } else {
            printk("x86_DMA] x86-DMA drvier Probe success");
            printk("x86_DMA] ----------------------------");
        }        
    }
    return SUCCESS;
}
void pim_dma_exit_x86(void)
{
    remove_pim_mem();
    remove_pim_dma();
}
#elif defined __aarch64__ /* For ARM architecture */
struct device *pl_dev;
static int pim_drv_init_arm(struct platform_device *pdev)
{
    int ret = 0;
    pl_dev = kzalloc(sizeof(struct device), GFP_KERNEL);
    pl_dev = &pdev->dev;
    ret = probe_pl_dma_arm(pdev, pl_dev);
    if (ret < 0) {
        printk(KERN_ERR " PL_DMA] Probing PL-DMA failed (Error code: %d)", ret);
    } else {
        ret = register_pl_drv();
        if (ret < 0) {
            printk(KERN_ERR " PL_DMA] Failed to register PL-DMA device (Error code: %d)", ret);
        } else {
            printk(" PL_DMA] PL-DMA driver Probe success");
            printk(" PL_DMA] ---------------------------");
        }
    }
    ret = probe_ps_dma();
    if (ret < 0) {
        printk(KERN_ERR " PS_DMA] Probing PS-DMA failed (Error code: %d)", ret);
    } else {
        ret = register_ps_drv();
        if (ret < 0) {
            printk(KERN_ERR " PS_DMA] Failed to register PS-DMA device (Error code: %d)", ret);
        } else {
            printk(" PS_DMA] PS-DMA drvier Probe success");
            printk(" PL_DMA] ---------------------------");
        }
    }
    return SUCCESS;
}

static int pim_drv_exit_arm(struct platform_device *pdev)
{
    remove_pim_dma();
    return 0;
}

static int pim_mem_init_arm(struct platform_device *pdev)
{
    int ret = 0;
#ifndef __PIM_MEM_KER__    
    ret = probe_pim_mem_arm(pdev);
    if (ret < 0) {
        printk(KERN_ERR "PIM_MEM] Probing PIM-MEM failed (Error code: %d)", ret);
    } else {
        ret = register_pim_mem();
        if (ret < 0) {
            printk(KERN_ERR "PIM_MEM] Failed to register PIM-MEM device (Error code: %d)", ret);
        } else {
            printk("PIM_MEM] PIM-MEM driver Probe success");
            printk("PIM_MEM] ----------------------------");
        }
    }
#else
    printk("PIM_MEM] Kernel manages PIM memory");
#endif    
    return ret;
}
static int pim_mem_exit_arm(struct platform_device *pdev)
{
#ifndef __PIM_MEM_KER__
    remove_pim_mem();
#endif    
    return 0;
}
static struct of_device_id cdma_drv_of_match[] = {
    { .compatible = "commit,cdma-driver", },
    { /* end of list */ },
};
MODULE_DEVICE_TABLE(of, cdma_drv_of_match);

static struct platform_driver cdma_driver = {
    .driver = {
        .name = PL_DRV_NAME,
        .owner = THIS_MODULE,
        .of_match_table = cdma_drv_of_match,
    },
    .probe      = pim_drv_init_arm,
    .remove     = pim_drv_exit_arm,
};

#ifdef CONFIG_OF
/*
 * Reference to system-user.dtsi file in the Petalinux project
 * e.x) system-user.dtsi
 *      ...
 *      mem-driver { 
 *          compatible = "commit, pim-mmap";
 *          ...
 *      }
 */
static struct of_device_id pim_mem_of_match[] = {
    { .compatible = "commit,pim-mmap", },
    { /* end of list */ },
};
MODULE_DEVICE_TABLE(of, pim_mem_of_match);
#else
# define pim_mem_of_match
#endif

static struct platform_driver pim_mem_driver = {
    .driver = {
        .name = PIM_MEM_NAME,
        .owner = THIS_MODULE,
        .of_match_table = pim_mem_of_match,
    },
    .probe = pim_mem_init_arm,
    .remove = pim_mem_exit_arm,
};
#endif // __aarch64__

static int __init pim_drv_init_module(void)
{
#ifdef __aarch64__
    platform_driver_register(&pim_mem_driver);
    return platform_driver_register(&cdma_driver);
#elif defined __x86_64__
    return pim_drv_init_x86();
#endif
}
static void __exit pim_drv_exit_module(void)
{
#ifdef __aarch64__
    platform_driver_unregister(&pim_mem_driver);    
    platform_driver_unregister(&cdma_driver);
#elif defined __x86_64__
    pim_dma_exit_x86();
#endif
}
module_init(pim_drv_init_module);
module_exit(pim_drv_exit_module);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KU COMMIT - Leewj");
