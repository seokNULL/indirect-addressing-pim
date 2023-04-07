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
    #include <linux/modversions.h>
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
#include <linux/iopoll.h>


#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_device.h>

#include "../../include/pim.h"
#include "dma_lib_kern.h"

#ifdef __x86_64__
//#include <asm/pat.h>
#include <asm/set_memory.h>
static struct pci_dev *pciem_dev = NULL;
static dev_t host_dev;
static struct cdev host_cdev;
static struct class *host_class = NULL;
static struct device *host_device = NULL;
struct host_dma *host_dma_t;
#endif //__x86_64__

struct cdma_dev_t *cdma_dev = NULL;
static dev_t pl_dev_t;
static struct cdev pl_cdev;
static struct class *pl_class = NULL;
static struct device *pl_device = NULL;

#ifdef __aarch64__
static dev_t ps_dev_t;
static struct cdev ps_cdev;
static struct class *ps_class = NULL;
static struct device *ps_device = NULL;
struct ps_dma *ps_dma_t;
#endif // __aarch64__

static int dev_uevent(struct device *dev, struct kobj_uevent_env *env)
{
    add_uevent_var(env, "DEVMODE=%#o", 0666);
    return 0;
}
static bool chan_filter(struct dma_chan *chan, void *param)
{
    printk(KERN_INFO " PS_DMA] dma_chan : %s ", dma_chan_name(chan));
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

/* File operation functions is in the pl_fos.c */
static struct file_operations pl_dma_fops = {
    .open = pl_dma_open,
    .read = pl_dma_read,
    .release = pl_dma_release,
    .mmap = pl_dma_mmap,
    .unlocked_ioctl   = pl_dma_ioctl,    
};

int register_pl_drv(void) {
    int ret;
    if ((ret = alloc_chrdev_region(&pl_dev_t, 0, 1, PL_DRV_NAME)) < 0) {
        printk("%s: could not allocate major number for mmap\n", __func__);
        goto out_vfree;
    }

    if((pl_class = class_create(THIS_MODULE, PL_DRV_NAME)) == NULL){
        printk("%s: calss_create() failed", __func__);
        goto out_unalloc_region;
    }
    pl_class->dev_uevent = dev_uevent;
    if ((pl_device = device_create(pl_class, NULL, pl_dev_t, NULL, PL_DRV_NAME)) == NULL){
        printk("%s: device_create() failed", __func__);
        goto out_unalloc_region;     
    }
    cdev_init(&pl_cdev, &pl_dma_fops);
    if ((ret = cdev_add(&pl_cdev, pl_dev_t, 1)) < 0) {
            printk("%s: could not allocate chrdev for mmap\n", __func__);
            goto out_unalloc_region;
    }
        
    return SUCCESS;
        
  out_unalloc_region:
    unregister_chrdev_region(pl_dev_t, 1);
  out_vfree:
    return -EFAULT; 
}


#ifdef __aarch64__
static struct file_operations ps_dma_fops = {
    .open = ps_dma_open,
    .release = ps_dma_release,
    .mmap = ps_dma_mmap,
    .unlocked_ioctl = ps_dma_ioctl,        
};

int register_ps_drv(void) {
    int ret;
    if ((ret = alloc_chrdev_region(&ps_dev_t, 0, 1, PS_DRV_NAME)) < 0) {
        printk("%s: could not allocate major number for mmap\n", __func__);
        goto out_vfree;
    }

    if((ps_class = class_create(THIS_MODULE, PS_DRV_NAME)) == NULL){
        printk("%s: calss_create() failed", __func__);
        goto out_unalloc_region;
    }
    ps_class->dev_uevent = dev_uevent;
    if ((ps_device = device_create(ps_class, NULL, ps_dev_t, NULL, PS_DRV_NAME)) == NULL){
        printk("%s: device_create() failed", __func__);
        goto out_unalloc_region;     
    }
    cdev_init(&ps_cdev, &ps_dma_fops);
    if ((ret = cdev_add(&ps_cdev, ps_dev_t, 1)) < 0) {
        printk("%s: could not allocate chrdev for mmap\n", __func__);
        goto out_unalloc_region;
    }
    return SUCCESS;

  out_unalloc_region:
    unregister_chrdev_region(ps_dev_t, 1);
  out_vfree:
    return -1;
}
#endif

#ifdef __x86_64__
static struct file_operations host_dma_fops = {
    .open = host_dma_open,
    .release = host_dma_release,
    .mmap = host_dma_mmap,
    .unlocked_ioctl   = host_dma_ioctl,        
};
/*
 * lspci -vv
 * 11:00.2 Encryption controller: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 00h-0fh) Platform Security Processor
 * Region 2: Memory at c2700000 (32-bit, non-prefetchable) [size=1M]
 */
int register_host_drv(void) {
    int ret;
    /* get the major number of the character device */
    if ((ret = alloc_chrdev_region(&host_dev, 0, 1, HOST_DRV_NAME)) < 0) {
            printk(KERN_ERR
        "x86_DMA: could not allocate major number for mmap\n");
            goto out_vfree;
    }

    if((host_class = class_create(THIS_MODULE, HOST_DRV_NAME)) == NULL){
        printk(KERN_DEBUG "x86_DMA: calss_create() failed");
        goto out_unalloc_region;
    }
    host_class->dev_uevent = dev_uevent;

    if ((host_device = device_create(host_class, NULL, host_dev, NULL, HOST_DRV_NAME)) == NULL){
        printk(KERN_DEBUG "x86_DMA: device_create() failed");
        goto out_unalloc_region;     
    }

    /* initialize the device structure and register the device with the kernel */
    cdev_init(&host_cdev, &host_dma_fops);
    if ((ret = cdev_add(&host_cdev, host_dev, 1)) < 0) {
            printk(KERN_ERR
        "x86_DMA: could not allocate chrdev for mmap\n");
            goto out_unalloc_region;
    }
        
    return ret;
        
  out_unalloc_region:
        unregister_chrdev_region(host_dev, 1);
  out_vfree:
        return ret;    
}

static struct pci_dev * pciem_find_device_recur(struct pci_bus *pci_bus)
{
    struct pci_bus *child_bus;
    struct pci_dev *dev;
    list_for_each_entry(dev, &pci_bus->devices, bus_list) {
        /* 0x10ee is vendor ID for Xilinx */
        if(dev->vendor==0x10ee){
            return dev;
        }
    }
    list_for_each_entry(child_bus, &pci_bus->children, node) {
        dev = pciem_find_device_recur(child_bus);
        if(dev  != NULL)
            return dev;
    }
    return NULL;
}
static struct pci_dev * pciem_find_device(void)
{
    struct pci_dev *pci_root = pci_get_domain_bus_and_slot(0, 0, 0);
    struct pci_bus *pci_bus = pci_root->bus;
    return pciem_find_device_recur(pci_bus);
}

int probe_pl_dma_x86(void)
{
    int err, status;
#ifdef INTR_ENABLE
    int rc;
#endif

    resource_size_t dma_start;
    resource_size_t dma_len;
    resource_size_t pci_start;
    resource_size_t pci_len;
    resource_size_t mem_start;
    resource_size_t mem_len;
    //resource_size_t desc_start;
    //resource_size_t desc_len;

    pciem_dev = pciem_find_device();
    if (pciem_dev == NULL) {
        printk(KERN_ERR " PL_DMA] Failed to find PL DMA");
        return -EDMA_PROBE;
    }
    err = pcim_enable_device(pciem_dev);
    if (err) {
        printk(KERN_ERR " PL_DMA] Failed to enable PL DMA");
        return err;
    }

    /* FPGA BAR */
    mem_start = pci_resource_start(pciem_dev, MEMORY_NUM);
    mem_len = pci_resource_len(pciem_dev, MEMORY_NUM);
    dma_start = pci_resource_start(pciem_dev, DMA_CONF_NUM);
    dma_len = pci_resource_len(pciem_dev, DMA_CONF_NUM);
    pci_start = pci_resource_start(pciem_dev, PCI_CONF_NUM);
    pci_len = pci_resource_len(pciem_dev, PCI_CONF_NUM);

    cdma_dev = kzalloc(sizeof(*cdma_dev), GFP_KERNEL);
    if (!cdma_dev) {
        printk(KERN_ERR " PL_DMA] Error dma device allocation ");
        goto error;
    }
    cdma_dev->pci_ctl_reg = NULL;
    cdma_dev->dma_ctl_reg = NULL;
    cdma_dev->desc_pim = NULL;
    cdma_dev->config_reg = NULL;
    cdma_dev->config_mem = NULL;

    /* IOREMAP register through PCIe BAR */
    cdma_dev->pci_ctl_reg = ioremap_nocache(pci_start,pci_len);
    if(cdma_dev->pci_ctl_reg == NULL) {
        printk(KERN_INFO "ioremap pci_ctl_reg error.\n");
        goto error;
    }
    cdma_dev->dma_ctl_reg = ioremap_nocache(dma_start, dma_len);
    if(cdma_dev->dma_ctl_reg == NULL) {
        printk(KERN_ERR " PL_DMA] ioremap dma_ctl_reg error.\n");
        goto error;
    }
    cdma_dev->config_reg = ioremap_nocache(mem_start + CONF_REG_OFFSET, CONF_REG_LEN);
    if (!cdma_dev->config_reg) {
        printk(KERN_ERR " PL_DMA] Could not allocate PIM conf_reg %llx - %x", mem_start + CONF_REG_OFFSET, CONF_REG_LEN);
        goto error;
    }
    cdma_dev->desc_pim = ioremap_wc(mem_start + DESC_MEM_OFFSET, DESC_MEM_LEN);
    if (!cdma_dev->desc_pim) {
        printk(KERN_ERR " PL_DMA] Could not allocate PIM desc_mem %llx - %llx", mem_start + DESC_MEM_OFFSET, mem_start + DESC_MEM_OFFSET + DESC_MEM_LEN - 1);
        goto error;
    }
    cdma_dev->config_mem = ioremap_nocache(mem_start + CONF_MEM_OFFSET, CONF_MEM_LEN);
    if (!cdma_dev->config_mem) {
        printk(KERN_ERR " PL_DMA] Could not allocate PIM conf_mem %llx - %llx", mem_start + CONF_MEM_OFFSET, mem_start + CONF_MEM_OFFSET + CONF_MEM_LEN - 1);        
        goto error;
    }
    cdma_dev->dram_base = mem_start - mem_start;
    cdma_dev->conf_mem_base = mem_start + CONF_MEM_OFFSET - mem_start;
    cdma_dev->desc_mem_base = mem_start + DESC_MEM_OFFSET - mem_start;

    printk(" PL_DMA] IOREMAP - CONFIG_REG: %llx - %llx (%llx)", mem_start + CONF_REG_OFFSET, mem_start + CONF_REG_OFFSET + CONF_REG_LEN - 1, mem_start + CONF_REG_OFFSET);
    printk(" PL_DMA] IOREMAP - CONFIG_MEM: %llx - %llx (%x)", mem_start + CONF_MEM_OFFSET, mem_start + CONF_MEM_OFFSET + CONF_MEM_LEN - 1, cdma_dev->conf_mem_base);
    printk(" PL_DMA] IOREMAP - DMA_DESC  : %llx - %llx (%llx)", mem_start + DESC_MEM_OFFSET, mem_start + DESC_MEM_OFFSET + DESC_MEM_LEN - 1, cdma_dev->desc_mem_base);


    /* 
     * Initialization Xilinx CDMA 
     * CDMA reset & IOCIRQ toggle using CDMA register
     */
    status = dma_ctrl_read(CDMA_REG_SR);
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_CR_RESET);
    dma_ctrl_write(CDMA_REG_SR, CDMA_REG_SR_IOCIRQ);
    wmb();
    dma_ctrl_write(CDMA_REG_CR, CDMA_REG_SR_IOCIRQ);

    printk(" PL_DMA] DMA Register");
    printk(" PL_DMA] CDMA_REG_CR : %x", dma_ctrl_read(CDMA_REG_CR));
    printk(" PL_DMA] CDMA_REG_SR : %x", status);
    
#ifdef INTR_ENABLE /* DMA TX completion interrupt mode */
    cdma_dev->irq = pciem_dev->irq;
    printk(" PL_DMA] CDMA IRQ %d \n", cdma_dev->irq);
    /* Register Interrupt Service Routine */
    rc = request_irq(pciem_dev->irq, pl_dma_irq_handler, IRQF_SHARED,"pl-dma-irq", cdma_dev);    
    if( rc < 0 )
        printk("[%s] Not request interrupt\n", __FUNCTION__ );
    else
        printk(" PL_DMA] CDMA Interrupt mode (registeration num: %d)", cdma_dev->irq);
#else /* DMA TX completion polling mode */
    printk(" PL_DMA] CMDA polling mode");
#endif
    return SUCCESS;

error:
#ifdef INTR_ENABLE
    free_irq(cdma_dev->irq, cdma_dev);
#endif
    iounmap(cdma_dev->pci_ctl_reg);
    iounmap(cdma_dev->dma_ctl_reg);
    iounmap(cdma_dev->desc_pim);
    iounmap(cdma_dev->config_reg);
    iounmap(cdma_dev->config_mem);
    device_destroy(pl_class, pl_dev_t);
    class_destroy(pl_class);
    cdev_del(&pl_cdev);
    unregister_chrdev_region(pl_dev_t, 1);   
    printk(" PL_DMA] Error DMA driver module\n");       
    return -EIOMAP_FAULT;    
}

int probe_host_dma(void)
{
    dma_cap_mask_t mask;

    host_dma_t = kzalloc(sizeof(struct host_dma), GFP_KERNEL);
#ifdef DMA_WC
    host_dma_t->mempolicy = WC;
#elif defined DMA_COHERENT
    host_dma_t->mempolicy = UC;
#else
    printk("x86_DMA] Mempolicy (WB/UC) is not defined");
    return -ERROR_x86_DMA;   
#endif
    dma_cap_zero(mask);
    dma_cap_set(DMA_MEMCPY, mask);
    for (;;) {
        host_dma_t->host_dma_chan = dma_request_channel(mask, chan_filter, NULL);
        if (host_dma_t->host_dma_chan) {
            break;
        } else {
            printk("x86_DMA] No available host DMA channel");
            break; 
        }
    }
    if (!host_dma_t->host_dma_chan) {
        printk("x86_DMA] Check HOST-DMA engine channel");
        return -EDMA_PROBE;
    }
    host_dma_t->dma_dev = host_dma_t->host_dma_chan->device->dev;
    printk("x86_DMA] HOST-DMA name: %s \n", dev_name(host_dma_t->dma_dev));
    dma_release_channel(host_dma_t->host_dma_chan);
    return SUCCESS;
} // __x86_64__
#elif defined __aarch64__
int probe_pl_dma_arm(struct platform_device *pdev, struct device *pl_pdev)
{
    struct device_node *np;
    int ret;
    struct resource res_reg;
    printk(" PL_DMA] Probe PL-DMA device");
    /* PL-DMA register */    
    np = of_parse_phandle(pl_pdev->of_node, PL_DMA_REG_NAME, 0);
    if (!np) {
        printk("No %s specified \n", PL_DMA_REG_NAME);
        return -EDMA_PROBE;
    }
    ret = of_address_to_resource(np, 0, &res_reg);
    if (ret) {
        printk("No memory addres_regs assigned to the region");
        return -EDMA_PROBE;
    }
    cdma_dev = kzalloc(sizeof(*cdma_dev), GFP_KERNEL);
    if (!cdma_dev) {
        printk(KERN_ERR " PL_DMA] Error dma device allocation ");
        goto error;
    }

    cdma_dev->dma_ctl_reg = ioremap(res_reg.start, resource_size(&res_reg));
    if (!cdma_dev->dma_ctl_reg) {
        printk(" PL_DMA] Could not allocate DMA control register (%llx - %llx)", res_reg.start, res_reg.end);
        return -EIOMAP_FAULT;
    }
    printk(" PL_DMA] IOREMAP - DMA CTL_REG: %llx - %llx ", res_reg.start, res_reg.end);
    /* PIM configuration register */
    np = of_parse_phandle(pl_pdev->of_node, CONF_REG_NAME, 0);
    if (!np) {
        printk("No %s specified \n", CONF_REG_NAME);
        return -EDMA_PROBE;
    }
    ret = of_address_to_resource(np, 0, &res_reg);
    if (ret) {
        printk("No memory addres_regs assigned to the region");
        return -EDMA_PROBE;
    }
    cdma_dev->config_reg = ioremap(res_reg.start, CONF_REG_LEN);
    if (!cdma_dev->config_reg) {
        printk(" PL_DMA] Could not allocate PIM configuration register (%llx - %x)", res_reg.start, CONF_REG_LEN-1);
        return -EIOMAP_FAULT;
    }
    cdma_dev->desc_pim = ioremap_wc(res_reg.start + DESC_MEM_OFFSET , DESC_MEM_LEN-1);
    if (!cdma_dev->desc_pim) {
        printk(" PL_DMA] Could not allocate PIM desc_mem (%llx - %x)", res_reg.start + DESC_MEM_OFFSET , DESC_MEM_LEN-1);
        return -EIOMAP_FAULT;
    }
    cdma_dev->config_mem = ioremap(res_reg.start + CONF_MEM_OFFSET, CONF_MEM_LEN - 1);
    if (!cdma_dev->config_mem) {
        printk(" PL_DMA] Could not allocate PIM conf_mem (%llx - %x)", res_reg.start + CONF_MEM_OFFSET, CONF_MEM_LEN - 1);
        return -EIOMAP_FAULT;
    }

    cdma_dev->dram_base = res_reg.start;
    cdma_dev->conf_mem_base = res_reg.start + CONF_MEM_OFFSET;
    cdma_dev->desc_mem_base = res_reg.start + DESC_MEM_OFFSET;




    printk(" PL_DMA] IOREMAP - CONFIG_REG : %llx - %llx (%llx)\n", res_reg.start + CONF_REG_OFFSET, res_reg.start + CONF_REG_OFFSET + CONF_REG_LEN - 1, cdma_dev->dram_base + CONF_REG_OFFSET);
    printk(" PL_DMA] IOREMAP - CONFIG_MEM : %llx - %llx (%x)\n", res_reg.start + CONF_MEM_OFFSET, res_reg.start + CONF_MEM_OFFSET + CONF_MEM_LEN - 1, cdma_dev->conf_mem_base);
    printk(" PL_DMA] IOREMAP - DMA_DESC   : %llx - %llx (%llx)\n", res_reg.start + DESC_MEM_OFFSET, res_reg.start + DESC_MEM_OFFSET + DESC_MEM_LEN - 1, cdma_dev->desc_mem_base);    
    printk(" PL_DMA] DMA Register\n");
    printk(" PL_DMA] CDMA_REG_CR : %x\n", dma_ctrl_read(CDMA_REG_CR));
    printk(" PL_DMA] CDMA_REG_SR : %x\n", dma_ctrl_read(CDMA_REG_SR));
    /* Register ISR */
#ifdef INTR_ENABLE /* DMA TX completion interrupt mode */
    cdma_dev->irq = platform_get_irq(pdev, 0);
    printk(" PL_DMA] IRQ: %d", cdma_dev->irq);
    cdma_dev->dev = pl_pdev;
    /* pl_dma_irq_handler() in pl_fos.c file */
    if (cdma_dev->irq > 0) {
        ret = devm_request_irq(&pdev->dev, cdma_dev->irq, pl_dma_irq_handler, 0,
                       "pl-dma-irq", cdma_dev);
        if (ret) {
            cdma_dev->irq = 0;
            printk(KERN_ERR " PL_DMA] ISR ERROR \n");
            return -EDMA_PROBE;
        }
        else
            printk(" PL_DMA] CDMA Interrupt mode (registeration num: %d)", cdma_dev->irq);
    } else {
        printk(KERN_ERR " PL_DMA] IRQ number ERROR \n");
        return -EDMA_PROBE;        
    }
#else /* DMA TX completion polling mode */
    printk(" PL_DMA] CMDA polling mode");
#endif
    return SUCCESS;

error:
    iounmap(cdma_dev->dma_ctl_reg);
    iounmap(cdma_dev->desc_pim);
    iounmap(cdma_dev->config_mem);
    iounmap(cdma_dev->config_reg);
    printk(" PL_DMA] Error DMA driver module\n");
    return -1;
}
int probe_ps_dma(void)
{
    int ret;
    dma_cap_mask_t mask;

    printk(" PS_DMA] Probe PS-DMA device");
    ps_dma_t = kzalloc(sizeof(struct ps_dma), GFP_KERNEL);
    dma_cap_zero(mask);
    dma_cap_set(DMA_MEMCPY, mask);
    for (;;) {
        ps_dma_t->ps_dma_chan = dma_request_channel(mask, chan_filter, NULL);
        if (ps_dma_t->ps_dma_chan) {
            break;
        } else {
            printk(" PS_DMA] No available host DMA channel");
            break; 
        }
    }
    if (!ps_dma_t->ps_dma_chan) {
        printk(" PS_DMA] Check PS-DMA engine channel");
        return -EDMA_PROBE;
    }
    ps_dma_t->dma_dev = ps_dma_t->ps_dma_chan->device->dev;
    printk(" PS_DMA] PS-DMA name: %s \n", dev_name(ps_dma_t->dma_dev));
    ret=ps_buffer_alloc(CPY_CHUNK_SIZE);
    if (ret < 0) {
        printk(" PS_DMA] CMA Buffer allocation error\n");
        return -EMEM_FAULT;
    } else {
        printk(" PS_DMA] CMA Buffer allocation (size:%d)", CPY_CHUNK_SIZE);
    }
    return SUCCESS;
}
#endif // __aarch64__

void remove_pim_dma(void)
{
    if (cdma_dev->dma_ctl_reg != NULL)
        iounmap(cdma_dev->dma_ctl_reg);
    if (cdma_dev->config_reg != NULL)
        iounmap(cdma_dev->config_reg);
    if (cdma_dev->desc_pim != NULL)
        iounmap(cdma_dev->desc_pim);    
    if (cdma_dev->config_mem != NULL)
        iounmap(cdma_dev->config_mem);    
    /* PL-DMA is commonly used in x86 and ARM */
    if (pl_class != NULL) {
        device_destroy(pl_class, pl_dev_t);
        class_destroy(pl_class);
        cdev_del(&pl_cdev);
        unregister_chrdev(MAJOR(pl_dev_t), PL_DRV_NAME);
        unregister_chrdev_region(pl_dev_t, 1);
    }

#ifdef __x86_64__
    #ifdef INTR_ENABLE
    if ((cdma_dev != NULL) && (cdma_dev->irq != 0))
        free_irq(cdma_dev->irq, cdma_dev);
    #endif
    if (cdma_dev->pci_ctl_reg != NULL)
        iounmap(cdma_dev->pci_ctl_reg);
    if (host_class != NULL) {
        device_destroy(host_class, host_dev);
        class_destroy(host_class);
        cdev_del(&host_cdev);
        unregister_chrdev_region(host_dev, 1);
    }
    /* Free host dma memory */
    if (host_dma_t->alloc_ptr0) {
        set_memory_wb((unsigned long)host_dma_t->alloc_ptr0, \
                                     host_dma_t->alloc_len0/PAGE_SIZE);
        if (host_dma_t->mempolicy == WC) // Write-back policy
            dma_free_wc (NULL, host_dma_t->alloc_len0, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0);
        else if (host_dma_t->mempolicy == UC) // Uncacheable policy
            dma_free_coherent (NULL, host_dma_t->alloc_len0, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0);
    }
    if (host_dma_t->alloc_ptr1) {  
        set_memory_wb((unsigned long)host_dma_t->alloc_ptr1, \
                                     host_dma_t->alloc_len1/PAGE_SIZE);
        if (host_dma_t->mempolicy == WC) {
            dma_free_wc (NULL, host_dma_t->alloc_len0, host_dma_t->alloc_ptr0, host_dma_t->dma_handle0);
        }
        else if (host_dma_t->mempolicy == UC) {
            dma_free_coherent (NULL, host_dma_t->alloc_len1, host_dma_t->alloc_ptr1, host_dma_t->dma_handle1);
        }
    }
    host_dma_t->alloc_cnt=0;
#elif defined __aarch64__
    #ifdef INTR_ENABLE
    if ((cdma_dev != NULL) && (cdma_dev->irq != 0))
        devm_free_irq(cdma_dev->dev, cdma_dev->irq, cdma_dev);
    #endif
    if (ps_class != NULL) {
        device_destroy(ps_class, ps_dev_t);
        class_destroy(ps_class);
        cdev_del(&ps_cdev);
        unregister_chrdev_region(ps_dev_t, 1);
    }
    ps_buffer_free();
    if (ps_dma_t->ps_dma_chan != NULL)
        dma_release_channel(ps_dma_t->ps_dma_chan);
#endif // __aarch64__
    printk("PIM_DMA] Removed PIM-DMA driver");
    printk("PIM_DMA] ----------------------");    
}

MODULE_DESCRIPTION("dma probe");
MODULE_AUTHOR("KU-Leewj");
MODULE_LICENSE("GPL");
