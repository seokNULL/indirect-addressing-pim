#ifndef _PIM_DMA_KERN_LIB_
#define _PIM_DMA_KERN_LIB_

#include <linux/module.h>

#include "../../include/pim.h"


#define MEMORY_NUM 0
#define DMA_CONF_NUM 1
#define PCI_CONF_NUM 3 // PCI DMA (DO NOT USE)

/* For host DMA */
#define DMA_COHERENT
#define WC 1
#define UC 2


/* AXI to PCIe address translation */
#define AXIBAR2PCIEBAR_0U 0x208
#define AXIBAR2PCIEBAR_0L 0x20c
#define AXIBAR2PCIEBAR_1U 0x210
#define AXIBAR2PCIEBAR_1L 0x214
#define AXIBAR2PCIEBAR_2U 0x218
#define AXIBAR2PCIEBAR_2L 0x21c
#define AXIBAR2PCIEBAR_3U 0x220
#define AXIBAR2PCIEBAR_3L 0x224
#define AXIBAR 0x00000000
#define AXI_HIGHADDR 0x1FFFFFF
#define AXI_MASK (AXI_HIGHADDR-AXIBAR)
#define ADDR_RANGE 0x1FFFFFF /* 32M */

/* For Descriptor */
#define CDMA_NEXT_DE_L       0x00
#define CDMA_NEXT_DE_H       0x04
#define CDMA_DESC_SA_L       0x08
#define CDMA_DESC_SA_H       0x0C
#define CDMA_DESC_DA_L       0x10
#define CDMA_DESC_DA_H       0x14
#define CDMA_DESC_LEN        0x18
#define CDMA_DESC_STATUS     0x1C
#define CDMA_DESC_INFO       0x24 /* Use reserved bit for PIM opcode */

/* AXI CDMA Register Address Map */
#define CDMA_REG_CR          0x00
#define CDMA_REG_SR          0x04
#define CDMA_CURDESC_PNTR_L  0x08
#define CDMA_CURDESC_PNTR_H  0x0C
#define CDMA_TAILDESC_PNTR_L 0x10
#define CDMA_TAILDESC_PNTR_H 0x14
#define CDMA_REG_SA_L        0x18
#define CDMA_REG_SA_H        0x1C
#define CDMA_REG_DA_L        0x20
#define CDMA_REG_DA_H        0x24
#define CDMA_REG_BYTETRANS   0x28

#define CDMA_REG_CR_DELAY_MASK 0x00000000 /* Delay timeout counter */

#define CDMA_TAILDESC_CMPLT  0x80000000

#define CDMA_COALESCE_SHIFT   0x10
#define CDMA_MAX_COALESCE   0xff /* This value is defined in the Xilinx CDMA document */
#define CDMA_MAX_POLLING    1000000 /* Polling counter */

#define CDMA_REG_DESC_TX_COMPL         BIT(31)
#define CDMA_REG_SR_EOL_LATE_ERR       BIT(15)
#define CDMA_REG_SR_ERR_IRQ            BIT(14)
#define CDMA_REG_SR_DLY_CNT_IRQ        BIT(13)
#define CDMA_REG_SR_IOCIRQ             BIT(12)
#define CDMA_REG_SR_SOF_LATE_ERR       BIT(11)
#define CDMA_REG_SR_SG_DEC_ERR         BIT(10)
#define CDMA_REG_SR_SG_SLV_ERR         BIT(9)
#define CDMA_REG_SR_EOF_EARLY_ERR      BIT(8)
#define CDMA_REG_SR_SOF_EARLY_ERR      BIT(7)
#define CDMA_REG_SR_DMA_DEC_ERR        BIT(6)
#define CDMA_REG_SR_DMA_SLAVE_ERR      BIT(5)
#define CDMA_REG_SR_DMA_INT_ERR        BIT(4)
#define CDMA_REG_SR_IDLE               BIT(1)

#define CDMA_REG_CR_INIT   BIT(12) /*Enable IOC */
#define CDMA_REG_CR_SG_EN  BIT(3)
#define CDMA_REG_CR_RESET  BIT(2)  /* RESET = 1 */

#define CDMA_REG_SR_TX_COMPL (CDMA_REG_SR_IDLE | CDMA_REG_SR_IOCIRQ)
#define CDMA_REG_CR_ALL_IRQ_MASK   (CDMA_REG_SR_IOCIRQ | CDMA_REG_SR_ERR_IRQ)
#define CDMA_REG_SR_ERR_RECOVER_MASK (CDMA_REG_SR_SOF_LATE_ERR | \
                                      CDMA_REG_SR_EOF_EARLY_ERR | \
                                      CDMA_REG_SR_SOF_EARLY_ERR | \
                                      CDMA_REG_SR_DMA_INT_ERR)      

#define CDMA_REG_SR_ALL_ERR_MASK (CDMA_REG_SR_SG_DEC_ERR | \
                                  CDMA_REG_SR_SG_SLV_ERR | \
                                  CDMA_REG_SR_DMA_DEC_ERR | \
                                  CDMA_REG_SR_DMA_SLAVE_ERR | \
                                  CDMA_REG_SR_DMA_INT_ERR)

#define WAIT_INTR       0x3000 /* Interrupt wait counter */
#define DRAM_OFFSET     0x80000000 /* For a case where the PCIe BAR address is greater than 0x80000000 in x86 */

#define CONF_MEM_OFFSET 0x400000
#define CONF_MEM_LEN    0x400000
#define CONF_REG_OFFSET 0x0
#define CONF_REG_LEN    0x200000

#define DESC_MEM_OFFSET 0x800000
#define DESC_MEM_LEN    0x800000

#define CONF_OFFSET_DESC_BASE 0x0
#define CONF_OFFSET_DESC_NUM 0x100
#define CONF_OFFSET_AIM_WORKING 0x4000

#define CONF_OFFSET_PROF_START 0x8000
#define CONF_OFFSET_PROF_CLR   0x9000
#define CONF_OFFSET_HPC_CLR    0x5000

#ifdef __x86_64__
#define CPY_CHUNK_SIZE 0x100000 /* In x86 platform, if the size of temporal buffer is too large, it is not allocated */
#elif __aarch64__
#define CPY_CHUNK_SIZE 0x8000000 /* In ARM platform, the size of temporal buffer is defined in system-user.dtsi file */
#endif
#ifdef DEBUG_PL_DMA
    #define PL_DMA_LOG(fmt, ...)           \
        printk(fmt, ##__VA_ARGS__);
#else
    #define PL_DMA_LOG(fmt, ...)           \
        no_printk(fmt, ##__VA_ARGS__);
#endif

#ifdef DEBUG_HOST_DMA
    #define HOST_DMA_LOG(fmt, ...)           \
        printk(fmt, ##__VA_ARGS__);
#else
    #define HOST_DMA_LOG(fmt, ...)           \
        no_printk(fmt, ##__VA_ARGS__);
#endif

#ifdef NUM_DESC
    #define DESC_PRINT(fmt, ...) printk(fmt, ##__VA_ARGS__);
#else
    #define DESC_PRINT(fmt, ...) no_printk(fmt, ##__VA_ARGS__);
#endif

#ifdef PERF_TIME
    #define PERF_START(start) ktime_get_ts64(&start);
#else
    #define PERF_START(start)
#endif

#ifdef PERF_TIME
    #define PERF_END(start, end, time) \
        ktime_get_ts64(&end); \
        time = time + BILLION * (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec);

    #define ADD_VAR(var, cnt) \
        var = var + cnt;
#else
    #define PERF_END(start, end, time)
    #define ADD_VAR(var, cnt)
#endif

#ifdef PERF_CNT
    #define ADD_CNT(var, num, cnt) \
        var = var + cnt; \
        num = num + 1;
#else
    #define ADD_CTN(var, cnt)
#endif
enum {
    SUCCESS = 0,
    EMEM_FAULT,
    EIOMAP_FAULT,
    EDMA_PROBE,
    EDMA_TX,
    EDMA_INTR,
    EIOCTL,
};

struct ps_dma {
    void *kern_addr;
    dma_addr_t bus_addr;
    uint32_t size;
    struct dma_chan *ps_dma_chan;
    struct device *dma_dev;

    void *alloc_ptr0;
    void *alloc_ptr1;
    long alloc_len0;
    long alloc_len1;    
};
extern struct ps_dma *ps_dma_t;

struct host_dma {
    void *kern_addr;
    dma_addr_t bus_addr;
    uint32_t size;
    struct dma_chan *host_dma_chan;
    struct device *dma_dev;

    void *alloc_ptr0;
    void *alloc_ptr1;
    long alloc_len0;
    long alloc_len1;
    dma_addr_t dma_handle0;
    dma_addr_t dma_handle1;
    int alloc_cnt;
    int mempolicy;
};
extern struct host_dma *host_dma_t;

struct device;
struct ioctl_info;

struct cdma_dev_t {
    struct device *dev;
    struct completion *compl;
    int irq;
    int err;

    uint32_t *pci_ctl_reg;
    uint32_t *dma_ctl_reg;
    void *desc_pim;
    uint32_t *desc_cpu;
    uint64_t *config_reg;
    uint64_t *config_mem;

    uint32_t opcode;
    uint64_t desc_mem_base;
    uint32_t conf_mem_base;
    uint64_t dram_base;
    void *tmp_buffer;
    uint64_t tmp_buff;
};
extern struct cdma_dev_t *cdma_dev;

static inline void pci_ctrl_write(u32 offset, u32 value) {
    iowrite32(value, (void *)(cdma_dev->pci_ctl_reg) + offset);
}
static inline void dma_ctrl_write(u32 offset, u32 value) {
    iowrite32(value, (void *)(cdma_dev->dma_ctl_reg) + offset);
}
static inline u32 dma_ctrl_read(u32 offset) {
    return ioread32((void *)(cdma_dev->dma_ctl_reg) + offset);
}
static inline void pim_conf_write(u32 offset, u32 value) {
    /* configuration register is 64 bit */
    cdma_dev->config_reg[offset >> 3] = value;
}
static inline u32 dma_desc_read(u32 offset, u32 pos) {
    uint32_t *tmp = (uint32_t *)cdma_dev->desc_pim;
    return tmp[(16 * offset) + (pos >> 0x2)];
}

extern int register_ps_drv(void);
extern int register_host_drv(void);
extern int register_pl_drv(void);
extern int register_pim_conf_drv(void);
extern irqreturn_t pl_dma_irq_handler(int irq, void *data);
#ifdef __x86_64__
extern int probe_pl_dma_x86(void);
extern int probe_host_dma(void);
extern int host_dma_open(struct inode *inode, struct file *filp);
extern int host_dma_release(struct inode *inode, struct file *filp);
extern int host_dma_mmap(struct file *filp, struct vm_area_struct *vma);
extern long host_dma_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
#elif defined __aarch64__
extern int probe_pl_dma_arm(struct platform_device *pdev, struct device *pl_pdev);
extern int probe_ps_dma(void);
extern int ps_dma_open(struct inode *inode, struct file *filp);
extern int ps_dma_release(struct inode *inode, struct file *filp);
extern int ps_dma_mmap(struct file *filp, struct vm_area_struct *vma);
extern long ps_dma_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
extern int ps_buffer_alloc(uint64_t size);
extern void ps_buffer_free(void);
#endif
extern void remove_pim_dma(void);

extern long pl_dma_ioctl(struct file *file, unsigned int cmd, unsigned long arg);
extern int pl_dma_open(struct inode *inode, struct file *file);
extern int pl_dma_release(struct inode *inode, struct file *file);
extern int pl_dma_mmap(struct file *filp, struct vm_area_struct *vma);
extern ssize_t pl_dma_read(struct file *f, char *buf, size_t nbytes, loff_t *ppos);

extern u64 va_to_pa(u64 vaddr);
extern struct dma_async_tx_descriptor *dma_host2host(uint64_t dst_pa, uint64_t src_pa, size_t len);

#endif // _PIM_KERNEL_LIB_
