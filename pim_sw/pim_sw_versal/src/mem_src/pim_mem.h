#ifndef _PIM_MEM_H_
#define _PIM_MEM_H_
/*
 * PIM driver interface file
 * This header file only used in src folder
 */
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
#include "../drv_src/pim_mem_lib_user.h"
#include "../../include/pim.h"

#ifdef __cplusplus
extern "C" {
#endif

extern void *mmap_drv(int size);
extern void __init_pim_drv(void);
extern void __release_pim_drv(void);

#ifdef __cplusplus
}
#endif

#endif