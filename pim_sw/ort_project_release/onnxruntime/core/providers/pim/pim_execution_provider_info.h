// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <limits>

#include "core/framework/arena_extend_strategy.h"
#include "core/framework/ortdevice.h"
#include "core/framework/provider_options.h"

namespace onnxruntime {
// Information needed to construct HIP execution providers.
struct PIMExecutionProviderInfo {
  OrtDevice::DeviceId device_id{0};
  size_t hip_mem_limit{std::numeric_limits<size_t>::max()};
  ArenaExtendStrategy arena_extend_strategy{ArenaExtendStrategy::kSameAsRequested};
  bool do_copy_in_default_stream{true};
  static PIMExecutionProviderInfo FromProviderOptions(const ProviderOptions& options);
  static ProviderOptions ToProviderOptions(const PIMExecutionProviderInfo& info);
};
}  // namespace onnxruntime
