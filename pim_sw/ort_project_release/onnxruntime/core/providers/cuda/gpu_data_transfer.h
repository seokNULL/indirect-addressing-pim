// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "cuda_pch.h"
#include "core/framework/data_transfer.h"

namespace onnxruntime {

enum CUDAStreamType : int {
  kCudaStreamDefault = 0,
  kCudaStreamCopyIn,
  kCudaStreamCopyOut,
  kTotalCudaStreams,
};

class GPUDataTransfer : public IDataTransfer {
 public:
  GPUDataTransfer(bool do_copy_in_default_stream = true);
  ~GPUDataTransfer();

  bool CanCopy(const OrtDevice& src_device, const OrtDevice& dst_device) const override;

  // Dumpen MSVC warning about not fully overriding
  using IDataTransfer::CopyTensor;
  common::Status CopyTensor(const Tensor& src, Tensor& dst, int exec_queue_id) const override;
  common::Status CopyTensor(const Tensor& src, Tensor& dst, OpKernelContext& ctx, int exec_queue_id) const override;

  cudaStream_t GetStream(int queue_id) const {
    ORT_ENFORCE(queue_id >= 0 && queue_id < kTotalCudaStreams);
    return streams_[queue_id];
  }

 private:
  cudaStream_t streams_[kTotalCudaStreams];
};

}  // namespace onnxruntime
