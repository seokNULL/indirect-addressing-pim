// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "core/framework/op_kernel.h"
#include "core/providers/cpu/math/matmul.h"
#include "core/providers/pim/helper/pim_interface.h"
#include "core/providers/pim/helper/aten/convert_numeric.h"

namespace onnxruntime {
namespace pim {

template <typename T>
class MatMul final : public OpKernel {
 public:
  MatMul(const OpKernelInfo& info) : OpKernel(info) {
      pim_interface = new PIMInterface();
  }

  Status Compute(OpKernelContext* context) const override;


  PIMInterface* pim_interface;
};

}  // namespace pim
int decoupled_PIM_input_layout (const Bfloat16* src,  Bfloat16* dst, int row_size, int col_size);
void decoupled_PIM_result_layout (Bfloat16* src, Bfloat16* dst, int row_size, int col_size);
}  // namespace onnxruntime
