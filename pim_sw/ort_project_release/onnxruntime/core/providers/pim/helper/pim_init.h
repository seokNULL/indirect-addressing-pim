
#pragma once


#include <vector>
#include <fcntl.h>      // O_WRONLY
#include <unistd.h>     // write(), close()
#include <stdarg.h>     // va_args
#include <sys/mman.h>
#include <sys/syscall.h>
#include <stdint.h>
#include <stdio.h>
#include <cstdlib> 

#include <pim.h>


namespace onnxruntime {

  void SetPimDevice();
  void FreePimDevice();
  int GetPimDevice();
  pim_args* GetPimCode();

} // namespace onnxruntime