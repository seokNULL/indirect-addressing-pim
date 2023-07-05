// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "core/framework/allocator.h"
#include "core/providers/pim/helper/pim_interface.h"

namespace onnxruntime {

class PIMAllocator : public IAllocator {
 public:
  PIMAllocator(OrtDevice::DeviceId device_id, const char* name)
      : IAllocator(
            OrtMemoryInfo(name, OrtAllocatorType::OrtDeviceAllocator,
                          OrtDevice(OrtDevice::PIM, OrtDevice::MemType::DEFAULT, device_id),
                          device_id, OrtMemTypeDefault)) {}
  void* Alloc(size_t size) override;
  // void* PimAlloc(size_t size) override;
  void Free(void* p) override;
  // FencePtr CreateFence(const SessionState* session_state) override;
 
  std::unordered_map<void*, size_t> size_table_;
  size_t max_size = 64 * 1024 * 1024; // 64MB
};

}  // namespace onnxruntime
