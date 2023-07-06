// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the Korea Univ, COMMIT Lab License.

#pragma once
// #include <atomic>
// #include <fstream>
// #include <initializer_list>
// #include <iostream>
// #include <tuple>

#include "core/common/common.h"
#include "core/framework/op_kernel.h"
#include "core/providers/pim/helper/pim_interface.h"
#include "core/providers/pim/helper/aten/convert_numeric.h"


namespace onnxruntime {
namespace pim {

template <typename T>
class Erf final : public OpKernel {
 public:
  Erf(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Tanh final : public OpKernel {
 public:
  Tanh(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Sqrt final : public OpKernel {
 public:
  Sqrt(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Relu final : public OpKernel {
 public:
  Relu(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Sigmoid final : public OpKernel {
 public:
  Sigmoid(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Neg final : public OpKernel {
 public:
  Neg(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Abs final : public OpKernel {
 public:
  Abs(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

template <typename T>
class Log final : public OpKernel {
 public:
  Log(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};

// template <typename T>
// class Div final : public OpKernel {
//  public:
//   Div(const OpKernelInfo& info) : OpKernel(info) {
//       pim_args = new PIMInterface();
//   }

//   Status Compute(OpKernelContext* context) const override;
//   PIMInterface* pim_args;
// };

template <typename T>
class Pow final : public OpKernel {
 public:
  Pow(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;
  PIMInterface* pim_interface;
};
  
void ComputeLutInternal(int dma_fd, pim_args* dma_info, Bfloat16* f_ptr, OpKernelContext* ctx);

}  // namespace pim
}  // namespace onnxruntime
