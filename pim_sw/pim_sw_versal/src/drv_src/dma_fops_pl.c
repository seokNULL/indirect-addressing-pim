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

#include <linux/iopoll.h>

#include "../../include/pim.h"
#include "dma_lib_kern.h"

// #include <asm/barrier.h>
// #include <asm/delay.h>

#ifdef PERF_TIME
struct timespec64 start_dma_tx, end_dma_tx;
uint64_t diff_dma_tx;
static uint64_t tx_time = 0;

struct timespec64 start_dma_init, end_dma_init;
uint64_t diff_dma_init;
static uint64_t dma_init_time = 0;

struct timespec64 start_desc_copy, end_desc_copy;
uint64_t diff_desc_copy;
static uint64_t desc_copy_time = 0;

#endif

static DEFINE_MUTEX(dma_lock);

#ifndef INTR_ENABLE
int __attribute__((optimize("O0"))) wait_sg(u32 desc_idx)
{
    int j=0;
    u32 status, errors;
    for (j = 0; j < CDMA_MAX_POLLING; j++) {
        status = dma_ctrl_read(CDMA_REG_SR);
        if (status & CDMA_REG_SR_ALL_ERR_MASK) {
            printk(KERN_ERR " PL_DMA] ERROR DMA - SR: %x", status);
            errors = status & CDMA_REG_SR_ALL_ERR_MASK;
            dma_ctrl_write(CDMA_REG_SR, errors & CDMA_REG_SR_ERR_RECOVER_MASK);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET);
            return -EDMA_TX;
        }
        if ((dma_desc_read(desc_idx, CDMA_DESC_STATUS) & CDMA_REG_DESC_TX_COMPL) == CDMA_REG_DESC_TX_COMPL){
            dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET); //DMA RESET
            return SUCCESS;
        }
    }
    printk(KERN_ERR " PL_DMA] DMA polling count reaches zero !! \n");    
    return -EDMA_TX;
}

int __attribute__((optimize("O0"))) wait_simple(void)
{
    int j=0;
    u32 status, errors;
    for (j = 0; j < CDMA_MAX_POLLING; j++) {
        status = dma_ctrl_read(CDMA_REG_SR);
        if (status & CDMA_REG_SR_ALL_ERR_MASK) {
            printk(KERN_ERR " PL_DMA] ERROR DMA - SR: %x", status);
            errors = status & CDMA_REG_SR_ALL_ERR_MASK;            
            dma_ctrl_write(CDMA_REG_SR, errors & CDMA_REG_SR_ERR_RECOVER_MASK);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET); //DMA RESET
            return -EDMA_TX;
        }        
        if ((status & CDMA_REG_SR_TX_COMPL) == CDMA_REG_SR_TX_COMPL){
            PL_DMA_LOG("Success single transaction");
            dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET); //DMA RESET
            return SUCCESS;
        }
    }
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET);    
    printk(KERN_ERR " PL_DMA] DMA polling count reaches zero !! \n");
    return -EDMA_TX;
}
#endif

#ifdef INTR_ENABLE
static struct completion trans_compl;

irqreturn_t pl_dma_irq_handler(int irq, void *data)
{ 
    u32 status, errors;
    PL_DMA_LOG("------------------------------------- \n");
    PL_DMA_LOG("Interrupt occured ! | SR: %x | CR: %x \n", dma_ctrl_read(CDMA_REG_SR), dma_ctrl_read(CDMA_REG_CR));
    status = dma_ctrl_read(CDMA_REG_SR);
    if (status & CDMA_REG_SR_ERR_IRQ) {
        printk("ERR IRQ - SR: %x, OPCODE: %x", status, cdma_dev->opcode);
        if (status & CDMA_REG_SR_SG_DEC_ERR)
            printk(KERN_ERR " PL_DMA] DMA SG-Decoding error ");
        if (status & CDMA_REG_SR_SG_SLV_ERR)
            printk(KERN_ERR " PL_DMA] DMA SG-Slave error ");
        if (status & CDMA_REG_SR_DMA_DEC_ERR)
            printk(KERN_ERR " PL_DMA] DMA Decoding error ");
        if (status & CDMA_REG_SR_DMA_SLAVE_ERR)
            printk(KERN_ERR " PL_DMA] DMA Slave error ");
        if (status & CDMA_REG_SR_DMA_INT_ERR)
            printk(KERN_ERR " PL_DMA] DMA Internal error ");
        errors = status & CDMA_REG_SR_ALL_ERR_MASK;
        dma_ctrl_write(CDMA_REG_SR, errors & CDMA_REG_SR_ERR_RECOVER_MASK);
        dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET);
        cdma_dev->err = -EDMA_INTR;
        PL_DMA_LOG("------------------------------------- \n");
        goto done;
    } 
    if (status & CDMA_REG_SR_DLY_CNT_IRQ) {
        /*
         * Device takes too long to do the transfer when user requires
         * responsiveness.
         */
        printk(KERN_ERR " PL_DMA] DMA Inter-packet latency too long\n");
        cdma_dev->err = -EDMA_INTR;
        dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ | CDMA_REG_SR_DLY_CNT_IRQ | CDMA_REG_SR_ERR_IRQ);
        PL_DMA_LOG("------------------------------------- \n");        
        goto done;
    }
    PL_DMA_LOG("COMPLETE - SR: %x, OPCODE: %x", status, cdma_dev->opcode);
    cdma_dev->err = 0;
    dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ | CDMA_REG_SR_DLY_CNT_IRQ | CDMA_REG_SR_ERR_IRQ);
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET); //DMA RESET
    PL_DMA_LOG("------------------------------------- \n");
    complete(&trans_compl);
done:
    return IRQ_HANDLED;
}
#endif


int dma_single_tx(u32 src_low, u32 src_high, u32 dst_low, u32 dst_high, u32 copy_len)
{
    int ret=0;
    PL_DMA_LOG("SRC_L: %x", src_low);
    PL_DMA_LOG("SRC_H: %x", src_high);
    PL_DMA_LOG("DST_L: %x", dst_low);
    PL_DMA_LOG("DST_H: %x", dst_high);
    dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
    PL_DMA_LOG("CR: %x \n", dma_ctrl_read(CDMA_REG_CR));
    PL_DMA_LOG("SR: %x \n", dma_ctrl_read(CDMA_REG_SR));
    dma_ctrl_write(CDMA_REG_SA_L, src_low);
    dma_ctrl_write(CDMA_REG_SA_H, src_high);
    dma_ctrl_write(CDMA_REG_DA_L, dst_low);
    dma_ctrl_write(CDMA_REG_DA_H, dst_high);
    dma_ctrl_write(CDMA_REG_BYTETRANS, copy_len);
#ifdef INTR_ENABLE
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_ALL_IRQ_MASK | CDMA_REG_CR_DELAY_MASK | (0x1 << CDMA_COALESCE_SHIFT));
    init_completion(&trans_compl);
    ret = wait_for_completion_timeout(&trans_compl, msecs_to_jiffies(WAIT_INTR));
    if (ret == 0) {
        printk(KERN_ERR " PL_DMA] DMA Timeout !! \n");
        return -EDMA_TX;
    }
    if (cdma_dev->err < 0) {
        printk(" PL_DMA] DMA Error !! \n");
        return -EDMA_INTR;
    }
#else
    ret = wait_simple();
    if (ret < 0)
        return -EDMA_TX;
#endif
    return SUCCESS;
}

int __attribute__((optimize("O0")))dma_sg_tx(u32 desc_idx, u32 last_desc)
{
    int ret;
#ifdef INTR_ENABLE
    int num_intr;
    if (desc_idx < CDMA_MAX_COALESCE) {
        num_intr = desc_idx << CDMA_COALESCE_SHIFT;
        dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_SG_EN | CDMA_REG_CR_ALL_IRQ_MASK | CDMA_REG_CR_DELAY_MASK | num_intr);
        dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
        PL_DMA_LOG("COALESCE: %x (%d) \n", num_intr, desc_idx);
        PL_DMA_LOG("1) :DESC_ADDR: (%llx - %x) \n", cdma_dev->desc_mem_base, last_desc-0x40);
        PL_DMA_LOG("CR: %x \n", dma_ctrl_read(CDMA_REG_CR));
        PL_DMA_LOG("SR: %x \n", dma_ctrl_read(CDMA_REG_SR));
        pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
        dma_ctrl_write(CDMA_CURDESC_PNTR_L, cdma_dev->desc_mem_base);
        dma_ctrl_write(CDMA_CURDESC_PNTR_H, HIGH_ADDR);
        wmb();
        dma_ctrl_write(CDMA_TAILDESC_PNTR_L, last_desc-0x40);
        dma_ctrl_write(CDMA_TAILDESC_PNTR_H, HIGH_ADDR);
        init_completion(&trans_compl);
        ret = wait_for_completion_timeout(&trans_compl, msecs_to_jiffies(WAIT_INTR));
        if (ret == 0) {
            printk(" PL_DMA] DMA Timeout (%d)!! \n", desc_idx);
            return -EDMA_TX;
        }
        if (cdma_dev->err < 0) {
            printk(KERN_ERR " PL_DMA] DMA Error !!\n");
            return -EDMA_INTR;
        }        
        pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
    } else {
        int chunk_desc, remain_desc, k, offset;
        u32 start_desc, end_desc;
        chunk_desc = (desc_idx / CDMA_MAX_COALESCE);
        remain_desc = (desc_idx % CDMA_MAX_COALESCE);
        for (k = 0; k < chunk_desc; k++) {
            num_intr = CDMA_MAX_COALESCE << CDMA_COALESCE_SHIFT;
            offset = k * CDMA_MAX_COALESCE * 0x40;
            start_desc = cdma_dev->desc_mem_base + offset;
            end_desc = start_desc + ((CDMA_MAX_COALESCE - 1) * 0x40);
            PL_DMA_LOG("%d - %d) DESC_ADDR: (%x - %x) \n", k, chunk_desc, start_desc, end_desc);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_SG_EN | CDMA_REG_CR_ALL_IRQ_MASK | CDMA_REG_CR_DELAY_MASK | num_intr);
            dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
            PL_DMA_LOG("CR: %x \n", dma_ctrl_read(CDMA_REG_CR));
            PL_DMA_LOG("SR: %x \n", dma_ctrl_read(CDMA_REG_SR));
            pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
            dma_ctrl_write(CDMA_CURDESC_PNTR_L, start_desc);
            dma_ctrl_write(CDMA_CURDESC_PNTR_H, HIGH_ADDR);
            wmb();
            dma_ctrl_write(CDMA_TAILDESC_PNTR_L, end_desc);
            dma_ctrl_write(CDMA_TAILDESC_PNTR_H, HIGH_ADDR);
            init_completion(&trans_compl);
            ret = wait_for_completion_timeout(&trans_compl, msecs_to_jiffies(WAIT_INTR));
            if (ret == 0) {
                printk(KERN_ERR " PL_DMA] DMA Timeout !! (%d - %d)\n", k, chunk_desc);
                return -EDMA_TX;
            }
            if (cdma_dev->err < 0) {
                printk(KERN_ERR " PL_DMA] DMA Error !! (%d - %d)\n", k, chunk_desc);
                return -EDMA_INTR;
            }
            pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
        }
        if (remain_desc) {
            num_intr = remain_desc << CDMA_COALESCE_SHIFT;
            start_desc = end_desc + 0x40;
            end_desc = last_desc-0x40;
            PL_DMA_LOG("%d) DESC_ADDR: (%x - %x) \n", remain_desc, start_desc, end_desc);
            dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_SG_EN | CDMA_REG_CR_ALL_IRQ_MASK | CDMA_REG_CR_DELAY_MASK | num_intr);
            dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
            PL_DMA_LOG("CR: %x \n", dma_ctrl_read(CDMA_REG_CR));
            PL_DMA_LOG("SR: %x \n", dma_ctrl_read(CDMA_REG_SR));
            pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
            dma_ctrl_write(CDMA_CURDESC_PNTR_L, start_desc);
            dma_ctrl_write(CDMA_CURDESC_PNTR_H, HIGH_ADDR);
            wmb();
            dma_ctrl_write(CDMA_TAILDESC_PNTR_L, end_desc);
            dma_ctrl_write(CDMA_TAILDESC_PNTR_H, HIGH_ADDR);            
            init_completion(&trans_compl);
            ret = wait_for_completion_timeout(&trans_compl, msecs_to_jiffies(WAIT_INTR));
            if (ret == 0) {
                printk(KERN_ERR " PL_DMA] DMA Timeout !! (%d - %d)\n", k, remain_desc);
                return -EDMA_TX;
            }
            if (cdma_dev->err < 0) {
                printk(KERN_ERR " PL_DMA] DMA Error !! (%d - %d)\n", k, chunk_desc);
                return -EDMA_INTR;
            }
            pim_conf_write(CONF_OFFSET_PROF_START, 0x0);
        }
    }
    pim_conf_write(CONF_OFFSET_AIM_WORKING, 0x1);
    return ret;
#else
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_SG_EN);
    dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
    dma_ctrl_write(CDMA_CURDESC_PNTR_L, cdma_dev->desc_mem_base);
    dma_ctrl_write(CDMA_CURDESC_PNTR_H, HIGH_ADDR);
    dma_ctrl_write(CDMA_TAILDESC_PNTR_L, last_desc-0x40);
    dma_ctrl_write(CDMA_TAILDESC_PNTR_H, HIGH_ADDR);
    wmb();
    // msleep(1);
    // udelay(10);
    ret=wait_sg(desc_idx);
    return ret;
#endif    
}
/* For file operations */
long pl_dma_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    pim_args pim_args;
    void *__user arg_ptr;
    u64 src_pa, dst_pa;
    u32 val;
    int err;
    void *dmabuf;
    dma_addr_t dma_handle;
    uint32_t *clr_signal;
    uint32_t *pim_signal;

    clr_signal = (void *)cdma_dev->config_reg + CONF_OFFSET_HPC_CLR;
    pim_signal = (void *)cdma_dev->config_reg + CONF_OFFSET_AIM_WORKING;
    arg_ptr = (void __user *) arg;
    if (copy_from_user((void *)&pim_args, (void __user *)arg, sizeof(pim_args))) {
        printk(KERN_ERR " PL_DMA] Failed copy pim_args");
        return -EIOCTL;
    }
    cdma_dev->opcode = cmd;
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET);
    switch (cmd)
    {
        case DMA_START:  /* Notify DMA start */
        {   
            #ifdef PERF_TIME
            dma_init_time    = 0;    
            desc_copy_time   = 0;     
            tx_time          = 0;
            PERF_START(start_dma_init);
            #endif

            /* Wait for DMA idle until loop count reaches zero or timeout */
            err = readl_poll_timeout((void *)(cdma_dev->dma_ctl_reg) + CDMA_REG_SR, val, (val & CDMA_REG_SR_IDLE), 0, CDMA_MAX_POLLING);
            if (err) {
                printk(KERN_ERR " PL_DMA] DMA in used \n");
                return -EIOCTL;
            }
            #ifdef PERF_TIME
            PERF_END(start_dma_init, end_dma_init, dma_init_time);
            #endif


            #ifdef PERF_TIME
            PERF_START(start_desc_copy);
            #endif

            /* 
             * Copy PISA-DMA instructions from system memory to descriptor memory 
             * pisa structure size is 64B (= descriptor granularity)
             */
            if (copy_from_user((void *)cdma_dev->desc_pim, (void *__user)pim_args.desc_host, (pim_args.desc_idx + 1) * 0x40)) {
                printk(KERN_ERR " PL_DMA] ERROR copy_from_user descriptor");
                return -EIOCTL;
            }
            #ifdef PERF_TIME
            PERF_END(start_desc_copy, end_desc_copy, desc_copy_time);
            #endif

            #ifdef PERF_TIME
            PERF_START(start_dma_tx);
            #endif

            clr_signal[0] = 0;
            pim_signal[0] = 0;
            /* Start DMA transaction */
            if (dma_sg_tx(pim_args.desc_idx, pim_args.desc_last) < 0) {
                printk(KERN_ERR " PL_DMA] Error transactions");
                return -EDMA_TX;
            }
            clr_signal[0] = 0;
            pim_signal[0] = 0;
            
            #ifdef PERF_TIME
            PERF_END(start_dma_tx, end_dma_tx, tx_time);
            printk("PROF] DMA WAIT: %llu ns\n", (long long unsigned int) dma_init_time);            
            printk("PROF] DESC COPY: %llu ns\n", (long long unsigned int) desc_copy_time);            
            printk("PROF] DMA TX: %llu ns\n", (long long unsigned int) tx_time);            
            #endif

            break;   
        }
        case DESC_MEM_INFO: /* Get descriptor memory information */
        {
            PL_DMA_LOG("Descriptor base addr: %llx", cdma_dev->desc_mem_base);
            pim_args.desc_base = cdma_dev->desc_mem_base;
            pim_args.dram_base = cdma_dev->dram_base;
            if (copy_to_user(arg_ptr, &pim_args, sizeof(pim_args))) {
                return -EFAULT;
            }
            break;
        }
        case VA_TO_PA: /* Virtual to physical address translation for DMA transaction */
        {
            pim_args.pa = va_to_pa(pim_args.va);
            PL_DMA_LOG("VA_TO_PA: %llx -> %llx \n", pim_args.va, pim_args.pa);
            if (copy_to_user(arg_ptr, &pim_args, sizeof(pim_args))) {
                return -EFAULT;
            }
            break;            
        }
        case MEMCPY_PL2PL: /* Memory copy using DMA engine */
        {
            PL_DMA_LOG("Memory copy PL -> PL");
            // 0x000000;
            // 0x100000;
            // 0x200000;
            // DO NOT WORK
            // 0x400000;
            src_pa = va_to_pa(pim_args.srcA_va);
            dst_pa = va_to_pa(pim_args.dstC_va);
            PL_DMA_LOG("src addr: %llx -> %llx ", pim_args.srcA_va, src_pa);
            PL_DMA_LOG("dst addr: %llx -> %llx ", pim_args.dstC_va, dst_pa);
            if (dma_single_tx(src_pa, HIGH_ADDR, dst_pa, HIGH_ADDR, pim_args.srcA_size) < 0)
                return -EDMA_TX;
            break;
        }
        case MEMCPY_PL2PS:
        {
            u32 copy_len, num_chunk, i;
            PL_DMA_LOG("Memory copy PL -> PS");
            copy_len = (pim_args.srcA_size > CPY_CHUNK_SIZE) ? CPY_CHUNK_SIZE : \
                                                      pim_args.srcA_size;
            num_chunk = (pim_args.srcA_size % CPY_CHUNK_SIZE) ? (pim_args.srcA_size / CPY_CHUNK_SIZE) + 1 : \
                                                      (pim_args.srcA_size / CPY_CHUNK_SIZE);
#ifdef __x86_64__
            dmabuf=dma_alloc_coherent(NULL, copy_len, &dma_handle, GFP_KERNEL);
#elif defined __aarch64__
            /* In the ARM platform, PS DMA buffer is used as dmabuf */
            dmabuf = ps_dma_t->kern_addr;
            dma_handle = ps_dma_t->bus_addr;
#endif
            if (dmabuf == NULL) {
                printk(KERN_ERR "DMA buffer is not allocated");
                return -EFAULT;
            }
            PL_DMA_LOG("copy_len: %d \n", copy_len);
            PL_DMA_LOG("num_chunk: %d \n", num_chunk);
            for (i = 0; i < num_chunk; i++) {
                src_pa = va_to_pa(pim_args.srcA_va + (i * CPY_CHUNK_SIZE));
                dst_pa = dma_handle;

#ifdef __x86_64__                
                /* pci control register not operated */
                //addr_hi = dst_pa >> 0x20;
                //addr_lo = dst_pa & 0xFFFFFFFF;
                //pci_ctrl_write(AXIBAR2PCIEBAR_0U, addr_hi);
                //pci_ctrl_write(AXIBAR2PCIEBAR_0L, addr_lo);
                dst_pa = dst_pa & AXI_MASK;
                dst_pa = dst_pa + AXIBAR;
                /* In x86 platform, high address of dst_pa is always 0 because dst_pa is 32 bits */
                if (dma_single_tx(src_pa, HIGH_ADDR, dst_pa, HIGH_ADDR, copy_len) < 0)
                    return -EDMA_TX;                
#elif defined __aarch64__
                //if (dma_single_tx(src_pa, HIGH_ADDR, dst_pa, dst_pa>>0x20, copy_len) < 0)
                if (dma_single_tx(src_pa, HIGH_ADDR, dst_pa, dst_pa>>0x20, copy_len) < 0)
                    return -EDMA_TX;
#endif
                if (copy_to_user(pim_args.dstC_ptr + (i * CPY_CHUNK_SIZE), dmabuf, copy_len)) {
                    printk(KERN_ERR " PL_DMA] Error copy_to_user in PL2PS");
                    return -EFAULT;
                }
            }
#ifdef __x86_64__
            dma_free_coherent(NULL, pim_args.srcA_size, dmabuf, dma_handle);
#endif
            break;
        }
        case MEMCPY_PS2PL:
        {
            u32 copy_len, num_chunk, i;
            PL_DMA_LOG("Memory copy PS -> PL");
            copy_len = (pim_args.srcA_size > CPY_CHUNK_SIZE) ? CPY_CHUNK_SIZE : \
                                                      pim_args.srcA_size;
            num_chunk = (pim_args.srcA_size % CPY_CHUNK_SIZE) ? (pim_args.srcA_size / CPY_CHUNK_SIZE) + 1 : \
                                                      (pim_args.srcA_size / CPY_CHUNK_SIZE);

#ifdef __x86_64__
            dmabuf=dma_alloc_coherent(NULL, copy_len, &dma_handle, GFP_KERNEL);
#elif defined __aarch64__
            /* In the ARM platform, PS DMA buffer is used as dmabuf */
            dmabuf = ps_dma_t->kern_addr;
            dma_handle = ps_dma_t->bus_addr;
#endif
            if (dmabuf == NULL) {
                printk(KERN_ERR "DMA buffer is not allocated");
                return -EFAULT;
            }
            PL_DMA_LOG("copy_len: %d \n", copy_len);
            PL_DMA_LOG("num_chunk: %d \n", num_chunk);

            for (i = 0; i < num_chunk; i++) {
                if (copy_from_user(dmabuf, pim_args.srcA_ptr + (i * CPY_CHUNK_SIZE), copy_len)) {
                   return -EFAULT;
                }
                src_pa = dma_handle;
                dst_pa = va_to_pa(pim_args.dstC_va);
#ifdef __x86_64__
                /* pci control register not operated */
                //addr_hi = src_pa >> 0x20;
                //addr_lo = src_pa & 0xFFFFFFFF;
                //pci_ctrl_write(AXIBAR2PCIEBAR_0U, addr_hi);
                //pci_ctrl_write(AXIBAR2PCIEBAR_0L, addr_lo);
                src_pa = src_pa & AXI_MASK;
                src_pa = src_pa + AXIBAR;
                /* In x86 platform, high address of src_pa is always 0 because src_pa is 32 bits */
                if (dma_single_tx(src_pa, HIGH_ADDR, dst_pa, HIGH_ADDR, copy_len) < 0)
                    return -EDMA_TX;
#elif defined __aarch64__
                if (dma_single_tx(src_pa, src_pa>>0x20, dst_pa, HIGH_ADDR, copy_len) < 0)
                    return -EDMA_TX;
#endif
            }
#ifdef __x86_64__
            dma_free_coherent(NULL, pim_args.srcA_size, dmabuf, dma_handle);
#endif
            break;
        }
        default :
            printk(KERN_ERR "Invalid IOCTL:%d\n", cmd);
            break;
    }
    return SUCCESS;
}

int pl_dma_open(struct inode *inode, struct file *file)
{
    //int ret;
    //ret = mutex_trylock(&dma_lock);
    //if (ret == 0) {
    //    printk(KERN_ERR "DMA is in use\n");
    //    return -EFAULT;
    //}
    return SUCCESS;
}

int pl_dma_release(struct inode *inode, struct file *file)
{
    //dma_ctrl_write(CDMA_REG_CR,  CDMA_REG_CR_RESET); //DMA RESET
    //wmb();
    //mutex_unlock(&dma_lock);
    return SUCCESS;
}

int pl_dma_mmap(struct file *filp, struct vm_area_struct *vma)
{
    return SUCCESS;
}

ssize_t pl_dma_read(struct file *f, char *buf, size_t nbytes, loff_t *ppos)
{
    return SUCCESS;
}

MODULE_DESCRIPTION("PL-DMA file operations");
MODULE_AUTHOR("KU-Leewj");
MODULE_LICENSE("GPL");
