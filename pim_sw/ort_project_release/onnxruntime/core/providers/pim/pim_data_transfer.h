// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "core/common/status.h"
#include "core/framework/tensor.h"
#include "core/framework/data_transfer.h"
#include "core/providers/pim/helper/pim_interface.h"
#include "core/framework/op_kernel.h"


namespace onnxruntime {

class PIMDataTransfer : public IDataTransfer {
 public:
  PIMDataTransfer() {
    pim_interface = new PIMInterface();
  }
  // Dampen MSVC warning about not fully overriding CopyTensor
  using IDataTransfer::CopyTensor;
  bool CanCopy(const OrtDevice& src_device, const OrtDevice& dst_device) const override;
  common::Status CopyTensor(const Tensor& src, Tensor& dst, int exec_queue_id) const override;
  common::Status CopyTensor(const Tensor& src, Tensor& dst, OpKernelContext& ctx, int exec_queue_id) const override;

  std::unordered_map<Bfloat16*, TensorShape> size_table_;
  PIMInterface* pim_interface;
};

void decoupled_PIM_weight_layout (const float* src,  uint16_t* dst, int row_size, int col_size);
}  // namespace onnxruntime
