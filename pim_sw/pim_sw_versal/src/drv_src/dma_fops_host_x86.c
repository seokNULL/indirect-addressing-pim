#ifdef __x86_64__

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
#include <linux/modversions.h>
#endif

#include <asm/io.h>
#include <asm/set_memory.h>
#include <linux/pci.h>

#include <linux/async_tx.h>
#include <linux/async.h>
#include <linux/uaccess.h>
#include <linux/kernel.h>
#include <linux/highmem.h>

#include "../../include/pim.h"
#include "dma_lib_kern.h"
extern u64 virtual_to_phys(u64 vaddr);
extern uint32_t* get_status_addr(void);

int dma_memcpy(dma_addr_t dst_pa, dma_addr_t src_pa, size_t len);
int memcpy_dma(struct page *dest, struct page *src, unsigned int dest_offset, unsigned int src_offset, size_t len);

static bool chan_filter(struct dma_chan *chan, void *param);
static struct completion compl;

static void dma_complete_func(void *completion)
{
  complete(completion);
}

/* character device open method */
int host_dma_open(struct inode *inode, struct file *filp)
{
    /* TODO: Driver semaphore */
    return 0;
}
/* character device last close method */
int host_dma_release(struct inode *inode, struct file *filp)
{
    HOST_DMA_LOG(KERN_INFO "x86_DMA] device release\n");    
    host_dma_t->alloc_cnt = 0;
    if (host_dma_t->alloc_ptr0) {
        set_memory_wb((unsigned long)host_dma_t->alloc_ptr0, host_dma_t->alloc_len0/PAGE_SIZE);
        if (host_dma_t->mempolicy == WC) {
            dma_free_wc(NULL, host_dma_t->alloc_len0, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0); 
        }
        else if (host_dma_t->mempolicy == UC) {
            dma_free_coherent (NULL, host_dma_t->alloc_len0, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }
        host_dma_t->alloc_ptr0 = NULL;
    }
    if (host_dma_t->alloc_ptr1) {
        set_memory_wb((unsigned long)host_dma_t->alloc_ptr1, host_dma_t->alloc_len1/PAGE_SIZE);
        if (host_dma_t->mempolicy == WC) {
            dma_free_wc (NULL, host_dma_t->alloc_len1, host_dma_t->alloc_ptr1, host_dma_t->dma_handle1); 
        }
        else if (host_dma_t->mempolicy == UC) {
            dma_free_coherent (NULL, host_dma_t->alloc_len1, host_dma_t->alloc_ptr1, host_dma_t->dma_handle1);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }
        host_dma_t->alloc_ptr1 = NULL;
    }
    return 0;
}

int host_dma_mmap(struct file *filp, struct vm_area_struct *vma)
{
    int ret;
    long length = vma->vm_end - vma->vm_start;
    if (host_dma_t->alloc_cnt == 0) {
        host_dma_t->alloc_len0 = length;
        if (host_dma_t->alloc_len0 >= 0x400000) {
            printk("x86_DMA] Do not use zero-copy when copying a size larger than 4MB");
            return -EMEM_FAULT;
        }
        if (host_dma_t->mempolicy == WC) {
            host_dma_t->alloc_ptr0 = dma_alloc_wc (NULL, host_dma_t->alloc_len0, &host_dma_t->dma_handle0, GFP_KERNEL);
        }
        else if (host_dma_t->mempolicy == UC) {
            host_dma_t->alloc_ptr0 = dma_alloc_coherent (NULL, host_dma_t->alloc_len0, &host_dma_t->dma_handle0, GFP_KERNEL);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }
        if (!host_dma_t->alloc_ptr0) {
            printk(KERN_ERR "x86_DMA] Src A dma_alloc_coherent error\n");
            return -EMEM_FAULT;
        }
        if (host_dma_t->mempolicy == WC) {
            vma->vm_page_prot = pgprot_writecombine(vma->vm_page_prot);
            set_memory_wc((unsigned long)host_dma_t->alloc_ptr0, host_dma_t->alloc_len0/PAGE_SIZE);
            HOST_DMA_LOG(KERN_INFO "x86_DMA] Using dma_mmap_coherent (Src A size: %lu) \n", host_dma_t->alloc_len0);
            ret = dma_mmap_coherent(NULL, vma, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0, host_dma_t->alloc_len0);
        }
        else if (host_dma_t->mempolicy == UC) {
            vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
            set_memory_uc((unsigned long)host_dma_t->alloc_ptr0, host_dma_t->alloc_len0/PAGE_SIZE);
            HOST_DMA_LOG(KERN_INFO "x86_DMA] Using dma_mmap_coherent (Src A size: %lu) \n", host_dma_t->alloc_len0);
            ret = dma_mmap_coherent(NULL, vma, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0, host_dma_t->alloc_len0);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }
    } else if (host_dma_t->alloc_cnt == 1) {
        host_dma_t->alloc_len1 = length;

        if (host_dma_t->mempolicy == WC) {
            host_dma_t->alloc_ptr1 = dma_alloc_wc (NULL, host_dma_t->alloc_len1, &host_dma_t->dma_handle1, GFP_KERNEL);
        }
        else if (host_dma_t->mempolicy == UC) {
            host_dma_t->alloc_ptr1 = dma_alloc_coherent (NULL, host_dma_t->alloc_len1, &host_dma_t->dma_handle1, GFP_KERNEL);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }        
        if (!host_dma_t->alloc_ptr1) {
            printk(KERN_ERR "x86_DMA] Src B dma_alloc_coherent error\n");
            return -EMEM_FAULT;
        }

        if (host_dma_t->mempolicy == WC) {
            vma->vm_page_prot = pgprot_writecombine(vma->vm_page_prot);        
            set_memory_wc((unsigned long)host_dma_t->alloc_ptr1, (host_dma_t->alloc_len1)/PAGE_SIZE);
            HOST_DMA_LOG(KERN_INFO "x86_DMA] Using dma_mmap_coherent (Src B size: %lu) \n", host_dma_t->alloc_len1);
            ret = dma_mmap_coherent(NULL, vma, host_dma_t->alloc_ptr1, host_dma_t->dma_handle1, host_dma_t->alloc_len1);
        }
        else if (host_dma_t->mempolicy == UC) {
            vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
            set_memory_uc((unsigned long)host_dma_t->alloc_ptr1, host_dma_t->alloc_len1/PAGE_SIZE);
            HOST_DMA_LOG(KERN_INFO "x86_DMA] Using dma_mmap_coherent (Src B size: %lu) \n", host_dma_t->alloc_len1);
            ret = dma_mmap_coherent(NULL, vma, host_dma_t->alloc_ptr1, host_dma_t->dma_handle1, host_dma_t->alloc_len1);
        }
        else {
            printk("x86_DMA] Mempolicy (WB/UC) is not defined");
            return -EMEM_FAULT;
        }
    } else {
        printk(KERN_ERR "x86_DMA] check host_dma_t->alloc_cnt (%d)\n", host_dma_t->alloc_cnt);
        return -EMEM_FAULT;
    }
    if (ret < 0) {
        printk(KERN_ERR "x86_DMA] mmap failed (%d)\n", ret);
        return ret;
    }
    host_dma_t->alloc_cnt++;
    return SUCCESS;    
}

long host_dma_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    pim_args user_info;
    int ret;
    void *__user arg_ptr, *alloc_ptr, *dst_ptr;
    uint32_t copy_len, num_chunk, i;
    dma_addr_t dma_handle, dma_handle_dst;
    uint64_t dst_pa;
    uint64_t srcA_va;
    arg_ptr = (void __user *) arg;
    if (copy_from_user(&user_info, arg_ptr, sizeof(user_info))) {
        return -EFAULT;
    }
    copy_len = (user_info.length > CPY_CHUNK_SIZE) ? CPY_CHUNK_SIZE : \
                                              user_info.length;
    num_chunk = (user_info.length % CPY_CHUNK_SIZE) ? (user_info.length / CPY_CHUNK_SIZE) + 1 : \
                                               (user_info.length / CPY_CHUNK_SIZE);

    if ((alloc_ptr = dma_alloc_coherent(NULL, copy_len, &dma_handle, GFP_DMA32)) == NULL) {
        printk(KERN_ERR "Temporal buffer allocation failed");
    }
    HOST_DMA_LOG("copy_len: %d \n", copy_len);
    HOST_DMA_LOG("num_chunk: %d \n", num_chunk);
    switch( cmd )
    {
        case HOST2HOST:
        {
            if ((user_info.length <= 0) || (user_info.dstC_ptr == 0) || (user_info.srcA_ptr == 0)) {
                ret = -EIOCTL;
                goto error;
            }
            dst_ptr = dma_alloc_coherent (NULL, copy_len, &dma_handle_dst, GFP_DMA32);
            for (i = 0; i < num_chunk; i++) {
                if (copy_from_user(alloc_ptr, user_info.srcA_ptr + (i * CPY_CHUNK_SIZE), copy_len)) {
                    ret = -EFAULT;
                    goto error;
                }
                if (dma_memcpy(dma_handle_dst, dma_handle, copy_len)) {
                    ret = -EDMA_TX;
                    goto error;
                }
                if (copy_to_user(user_info.dstC_ptr + (i * CPY_CHUNK_SIZE), dst_ptr, copy_len)) {
                    ret = -EFAULT;
                    goto error;
                }
            }
            dma_free_coherent (NULL, copy_len, dst_ptr, dma_handle_dst);
            break;            
        }
        case HOST2FPGA:
        {
            if ((user_info.length <= 0) || (user_info.dstC_ptr == 0) || (user_info.srcA_ptr == 0)) {
                ret = -EIOCTL;
                goto error;
            }
            dst_pa = va_to_pa((uint64_t)user_info.dstC_ptr);
            dst_ptr = dma_alloc_coherent (NULL, copy_len, &dma_handle_dst, GFP_DMA32);
            for (i = 0; i < num_chunk; i++) {
                if (copy_from_user(alloc_ptr, user_info.srcA_ptr + (i * CPY_CHUNK_SIZE), copy_len)) {
                    ret = -EFAULT;
                    goto error;
                }
                if (dma_memcpy(dst_pa + (i * CPY_CHUNK_SIZE), dma_handle, copy_len)) {
                    ret = -EDMA_TX;
                    goto error;
                }
            }
            dma_free_coherent (NULL, copy_len, dst_ptr, dma_handle_dst);
            break;
        }
        case FPGA2HOST:
        {
            if ((user_info.length <= 0) || (user_info.dstC_ptr == 0) || (user_info.srcA_ptr == 0)) {
                printk("IOCTL info Error \n");
                return -EIOCTL;
            }
            srcA_va = va_to_pa((uint64_t)user_info.srcA_ptr);
            for (i = 0; i < num_chunk; i++) {
                if (dma_memcpy(dma_handle, srcA_va, copy_len)) {
                    ret = -EDMA_TX;
                    goto error;
                }
                if (copy_to_user(user_info.dstC_ptr + (i * CPY_CHUNK_SIZE), alloc_ptr, copy_len)) {
                    ret = -EFAULT;
                    goto error;
                }
            }
            break;
        }
        case H2H_ZCPY:
        {
            if (user_info.length <= 0) {
                printk("IOCTL info Error \n");
                return -EIOCTL;
            }
            if (dma_memcpy(host_dma_t->dma_handle1, host_dma_t->dma_handle0, user_info.length)) {
                return -EDMA_TX;
            }
            break;
        }
        default :
            printk("Invalid IOCTL:%d\n", cmd);
            break;
    } 
    dma_free_coherent (NULL, copy_len, alloc_ptr, dma_handle);
    return SUCCESS;
error:
    printk("x86_DMA] Error: %d \n", ret);
    dma_free_coherent (NULL, copy_len, alloc_ptr, dma_handle);    
    return -EFAULT;
}


static bool chan_filter(struct dma_chan *chan, void *param)
{
    //printk(KERN_INFO "DMA_TEST] dma_chan : %s ", dma_chan_name(chan));
    if ( (strcmp(dma_chan_name(chan), "dma0chan0") == 0 )
      || (strcmp(dma_chan_name(chan), "dma0chan1") == 0 )
      || (strcmp(dma_chan_name(chan), "dma0chan2") == 0 )
      || (strcmp(dma_chan_name(chan), "dma0chan3") == 0 )
      || (strcmp(dma_chan_name(chan), "dma0chan4") == 0 )
      || (strcmp(dma_chan_name(chan), "dma0chan5") == 0 ) ) {
    return true;
  } 
  else 
    return false;
}

int dma_memcpy(dma_addr_t dst_pa, dma_addr_t src_pa, size_t len)
{
    struct dma_chan *chan;
    dma_cap_mask_t mask;
    enum dma_status status;
    struct dma_device *device = NULL; 
    struct dma_async_tx_descriptor *tx = NULL;
    dma_cookie_t cookie;
    unsigned long dma_prep_flags = 0;

    dma_cap_zero(mask);
    dma_cap_set(DMA_MEMCPY, mask);  
    for (;;) {
        chan = dma_request_channel(mask, chan_filter, NULL);
        if (chan) {
            break;
        } else {
            printk("No available");
            break; 
        }
    }
    device = chan ? chan->device : NULL;

    if (!device) {
        printk(KERN_ERR "%s: Error finding DMA channel", __func__);
        return -EDMA_PROBE;
    }

    dma_prep_flags |= DMA_PREP_INTERRUPT;
    tx = device->device_prep_dma_memcpy(chan, 
                                        dst_pa,
                                        src_pa, 
                                        len, dma_prep_flags);
    init_completion(&compl);
    tx->callback = dma_complete_func;
    tx->callback_param = &compl;
    if (tx) {
        cookie = tx->tx_submit(tx);
        if (dma_submit_error(cookie)) {
            printk(KERN_ERR "dma submit failed \n");
        }           
        dma_async_issue_pending(chan);
        wait_for_completion(&compl);
        status = dma_async_is_tx_complete(chan, cookie, NULL, NULL);
        if (status != DMA_COMPLETE){
            printk(KERN_ERR "%s: DMA error waiting for ascync tx. Status is %d \n", __func__, status);
            dmaengine_terminate_all(chan);        
            return -EDMA_TX;
        }
        dma_release_channel(chan);
    } else {
        printk(KERN_ERR "%s: Error tx_submit", __func__);
        return -EDMA_TX;
    }
    return 0;
}
int memcpy_dma(struct page *dest, struct page *src, unsigned int dest_offset,
         unsigned int src_offset, size_t len)
{
    struct dma_chan *chan;
    dma_cap_mask_t mask;
    enum dma_status status;
    struct dma_device *device = NULL; 
    struct dma_async_tx_descriptor *tx = NULL;
    struct dmaengine_unmap_data *unmap = NULL;
    dma_cookie_t cookie;

    dma_cap_zero(mask);
    dma_cap_set(DMA_MEMCPY, mask);  
    for (;;) {
        chan = dma_request_channel(mask, chan_filter, NULL);
        if (chan) {
            break;
        } else {
            printk("No available");
            break; 
        }
    }

    //struct dma_chan *chan = async_tx_find_channel(submit, DMA_MEMCPY,
    //                          &dest, 1, &src, 1, len);
    device = chan ? chan->device : NULL;

    if (device) {
        unmap = dmaengine_get_unmap_data(device->dev, 2, GFP_NOWAIT);
    } else {
        printk(KERN_ERR "DMA_TEST] Error finding DMA channel");
        return -EDMA_PROBE;
    }

    if (unmap && is_dma_copy_aligned(device, src_offset, dest_offset, len)) {
        unsigned long dma_prep_flags = 0;

        dma_prep_flags |= DMA_PREP_INTERRUPT;

        unmap->to_cnt = 1;
        unmap->addr[0] = dma_map_page(device->dev, src, src_offset, len,
                          DMA_TO_DEVICE);
        unmap->from_cnt = 1;
        unmap->addr[1] = dma_map_page(device->dev, dest, dest_offset, len,
                          DMA_FROM_DEVICE);
        unmap->len = len;

        tx = device->device_prep_dma_memcpy(chan, unmap->addr[1],
                            unmap->addr[0], len,
                            dma_prep_flags);

        init_completion(&compl);
        tx->callback = dma_complete_func;
        tx->callback_param = &compl;        
    }
    else {
        printk(KERN_ERR "%s: Error unmap or dma aligned", __func__);
    }
    if (tx) {
        //printk(KERN_INFO "%s: (async) len: %zu\n", __func__, len);

        //dma_set_unmap(tx, unmap);
        //async_tx_submit(chan, tx, submit);
        cookie = tx->tx_submit(tx);
        if (dma_submit_error(cookie)) {
            printk("dma submit failed \n");
        }           
        dma_async_issue_pending(chan);
        wait_for_completion(&compl);
        status = dma_async_is_tx_complete(chan, cookie, NULL, NULL);
        if (status != DMA_COMPLETE){
            printk("DMA_TEST] DMA error waiting for ascync tx. Status is %d \n", status);
            dmaengine_terminate_all(chan);        
            return -EDMA_TX;
        }
        dma_release_channel(chan);
    } else {
        printk(KERN_ERR "%s: Error tx_submit", __func__);
        return -EDMA_TX;
    }
    dmaengine_unmap_put(unmap);

    return SUCCESS;
}


#endif //__x86_64__