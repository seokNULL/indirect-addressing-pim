// Changed TensorImpl to Tensor
#pragma once

#include <string>
#include <type_traits>
#include <utility>
#include <stdlib.h>

// #include "pim_lookup.h"
// #include "pim_init.h"

#include <sys/syscall.h>
#include <unistd.h>     // write(), close()
#include <fcntl.h>      // O_WRONLY
#include <stdarg.h>     // va_args

#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/ioctl.h> // PIM!!

#include "core/framework/tensor.h"
#include "core/framework/op_kernel.h"

#include <pim.h>

#define BURST_SIZE 32 /* Byte size */
#define TYPE_SIZE sizeof(short) /* Pre-defined bfloat16 type */
#define REG_SIZE (BURST_SIZE / TYPE_SIZE) /* vecA and vACC register size */
#define vecA_SIZE 32
#define vACC_SIZE 32
#define NUM_BANKS 16
#define PIM_WIDTH (REG_SIZE * NUM_BANKS * TYPE_SIZE)
#define CHUNK 256


namespace onnxruntime{ 
    
extern pim_args* pim_code;
extern int pl_dma_fd;

class PIMInterface {
 public:
  explicit PIMInterface() : pl_dma_fd_(pl_dma_fd), pim_code_(pim_code) {}  
    void Release();
    int GetFileDescriptor() {return pl_dma_fd_;};
    pim_args* GetPimCode() {return pim_code_;};

    int pl_dma_fd_;
    pim_args* pim_code_;

};

} // onnxruntime