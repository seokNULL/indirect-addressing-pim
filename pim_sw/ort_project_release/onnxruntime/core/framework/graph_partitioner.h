// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#if !defined(ORT_MINIMAL_BUILD) || defined(ORT_EXTENDED_MINIMAL_BUILD)

#include "core/common/common.h"
#include "core/graph/graph_viewer.h"
#include "core/framework/op_kernel.h"
#include "core/framework/fuse_nodes_funcs.h"

namespace onnxruntime {

class ExecutionProviders;
class KernelRegistry;
class KernelRegistryManager;

class GraphPartitioner {
 public:
  enum class Mode {
    kNormal = 0,
    kAssignOnly = 1,    // assign nodes. no call to Compile. used to create ORT format model support for compiling EPs
    kOrtFormatLoad = 2, // loading ORT format model. Partition with compiling EPs, GraphViewer based Compile.
    kPartition = 3      // user defined partition.
  };

  //The order of providers represents the user preference.
  GraphPartitioner(KernelRegistryManager& kernel_registry_mgr, const ExecutionProviders& providers)
      : kernel_registry_mgr_(kernel_registry_mgr),
        providers_(providers) {
  }

  // Run partitioning. Provide compiled_kernel_hashes if mode is kOrtFormatLoad.
  Status Partition(Graph& graph, bool export_dll, FuncManager& func_mgr,
                   Mode mode = Mode::kNormal,
                   std::unordered_map<std::string, uint64_t>* compiled_kernel_hashes = nullptr) const;

  std::map<std::string, std::vector<int>> partition_map_;

 private:
  ORT_DISALLOW_COPY_ASSIGNMENT_AND_MOVE(GraphPartitioner);

#if !defined(ORT_MINIMAL_BUILD)
  Status PartitionOnnxFormatModel(Graph& graph, bool export_dll, FuncManager& func_mgr,
                                  KernelRegistry& fused_kernel_registry, Mode mode, int& fused_node_unique_id) const;
#endif

  Status PartitionOrtFormatModel(Graph& graph, FuncManager& func_mgr, KernelRegistry& fused_kernel_registry,
                                 std::unordered_map<std::string, uint64_t>& compiled_kernel_hashes,
                                 int& fused_node_unique_id) const;

  KernelRegistryManager& kernel_registry_mgr_;
  const ExecutionProviders& providers_;
};
}  // namespace onnxruntime

#endif  // !defined(ORT_MINIMAL_BUILD) || defined(ORT_EXTENDED_MINIMAL_BUILD)
