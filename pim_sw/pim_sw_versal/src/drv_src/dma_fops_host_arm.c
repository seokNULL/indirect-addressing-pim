#ifdef __aarch64__

#include <linux/module.h>
#include <linux/init.h>
#include <linux/mmzone.h>
//#include <asm/mmzone.h>
#include <linux/module.h>
#include <linux/uaccess.h>
#include <linux/if_arp.h>
#include <linux/interrupt.h>
#include <linux/sched.h>
#include <linux/kref.h>
#include <linux/kallsyms.h>
#include <asm/pgtable.h>
//#include <asm/pat.h>
#include <asm/tlbflush.h>
#include <linux/mm.h>
#include <linux/types.h>
#include <linux/stat.h>
#include <linux/fcntl.h>
#include <asm/unistd.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/unistd.h>
#include <linux/errno.h>
#include <asm/uaccess.h>
#include <linux/cdev.h>
#include <linux/mutex.h>

#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_device.h>
#include "../../include/pim.h"
#include "dma_lib_kern.h"

int ps_alloc_cnt=0;
dma_addr_t ps_dma_handle0;
dma_addr_t ps_dma_handle1;

int ps_buffer_alloc(uint64_t size)
{
    ps_dma_t->size = size;
    ps_dma_t->kern_addr = dma_alloc_coherent(ps_dma_t->dma_dev, ps_dma_t->size, &ps_dma_t->bus_addr, GFP_KERNEL);
    if (!ps_dma_t->kern_addr) {
        printk(KERN_ERR " PS_DMA] Error DMA buffer in %s", __func__);
        return -1;
    } else {
        printk(" PS_DMA] ps_dma buffer (kern_addr:%llx, bus_addr:%llx", (uint64_t)ps_dma_t->kern_addr, (uint64_t)ps_dma_t->bus_addr);
    }
    return SUCCESS;
}
void ps_buffer_free(void)
{
    if (ps_dma_t->kern_addr) {
        dma_free_coherent(ps_dma_t->dma_dev, ps_dma_t->size, ps_dma_t->kern_addr, ps_dma_t->bus_addr);
        ps_dma_t->size = 0L;
        ps_dma_t->kern_addr= 0;
        ps_dma_t->bus_addr= 0;
    }
}

/* character device open method */
int ps_dma_open(struct inode *inode, struct file *filp)
{
	printk(KERN_INFO " PS_DMA] device open\n");
    return SUCCESS;
}
/* character device last close method */
int ps_dma_release(struct inode *inode, struct file *filp)
{
    printk(KERN_INFO " PS_DMA] device release\n");    

    if (ps_dma_t->alloc_ptr0)
        dma_free_coherent(ps_dma_t->dma_dev, ps_dma_t->alloc_len0, ps_dma_t->alloc_ptr0, ps_dma_handle0);        
    if (ps_dma_t->alloc_ptr1)  
        dma_free_coherent(ps_dma_t->dma_dev, ps_dma_t->alloc_len1, ps_dma_t->alloc_ptr1, ps_dma_handle1);

    ps_alloc_cnt=0;

    if (ps_dma_t->alloc_ptr0)
        ps_dma_t->alloc_ptr0 = NULL;
    if (ps_dma_t->alloc_ptr1)
        ps_dma_t->alloc_ptr1 = NULL;
    
    return SUCCESS;
}

int ps_dma_mmap(struct file *filp, struct vm_area_struct *vma)
{
    int ret = 0;
    long length = vma->vm_end - vma->vm_start;
    //struct page *page;

    if (ps_alloc_cnt == 0) {
        ps_dma_t->alloc_len0 = length;
        ps_dma_t->alloc_ptr0 = dma_alloc_coherent(ps_dma_t->dma_dev, ps_dma_t->alloc_len0, &ps_dma_handle0, GFP_KERNEL);

        if (!ps_dma_t->alloc_ptr0) {
            printk(" PS_DMA] Src buf dma_alloc_coherent error\n");
            ret = -ENOMEM;
            return ret;
        }
        printk(" PS_DMA] Using WB-remap_pfn_range (Src buf size: %lu) \n", ps_dma_t->alloc_len0);
        ret = dma_mmap_coherent(ps_dma_t->dma_dev, vma, ps_dma_t->alloc_ptr0, ps_dma_handle0, ps_dma_t->alloc_len0);
    } else if (ps_alloc_cnt == 1) {
        ps_dma_t->alloc_len1 = length;
        ps_dma_t->alloc_ptr1 = dma_alloc_coherent(ps_dma_t->dma_dev, ps_dma_t->alloc_len1, &ps_dma_handle1, GFP_KERNEL);
        if (!ps_dma_t->alloc_ptr1) {
            printk(" PS_DMA] Dst buf dma_alloc_coherent error\n");
            ret = -ENOMEM;
            return ret;
        }
        printk(" PS_DMA] Using WB-remap_pfn_range (Dst buf size: %lu) \n", ps_dma_t->alloc_len1);
        ret = dma_mmap_coherent(ps_dma_t->dma_dev, vma, ps_dma_t->alloc_ptr1, ps_dma_handle1, ps_dma_t->alloc_len1);
    }
    if (ret < 0) {
	  printk(" PS_DMA] mmap failed (%d)\n", ret);
	  return ret;
    }

    ps_alloc_cnt++;
    return SUCCESS;
}

long ps_dma_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    pim_args user_info;
    void *__user arg_ptr;

    arg_ptr = (void __user *) arg;   
    if (copy_from_user(&user_info, arg_ptr, sizeof(user_info))) {
        return -EFAULT;
    }
    switch (cmd)
    {      
        default:
            printk("Do not implemented PS DMA IOCTL\n");
            break;
    }
    return SUCCESS;
}

MODULE_DESCRIPTION("PS-DMA file operations");
MODULE_AUTHOR("KU-Leewj");
MODULE_LICENSE("GPL");


#endif