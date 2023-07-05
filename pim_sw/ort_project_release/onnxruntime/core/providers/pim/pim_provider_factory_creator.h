// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <memory>

#include "core/providers/providers.h"

#include "core/providers/pim/pim_execution_provider_info.h"

namespace onnxruntime {

std::shared_ptr<IExecutionProviderFactory> CreateExecutionProviderFactory_PIM(const PIMExecutionProviderInfo& info);

}  // namespace onnxruntime

