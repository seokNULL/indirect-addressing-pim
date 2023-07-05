#pragma once

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "core/framework/execution_provider.h"
#include "core/graph/onnx_protobuf.h"
#include "core/providers/pim/pim_execution_provider_info.h"
#include "core/graph/graph_utils.h"
#include <set>
#include <vector>

#include "core/graph/constants.h"
#include "core/framework/allocatormgr.h"
#include "core/framework/bfc_arena.h"
#include "core/framework/execution_provider.h"

#include "core/providers/pim/helper/pim_init.h"
#include <unistd.h>     // write(), close()
#include <fcntl.h>      // O_WRONLY
#include <stdarg.h>     // va_args

#define LUT_SIZE 65536
#define LUT_OPS_NUM 8

namespace onnxruntime {

const int CPU_ALLOCATOR_DEVICE_ID = 0;

class PIMExecutionProvider : public IExecutionProvider {
 public:
  PIMExecutionProvider(const PIMExecutionProviderInfo& info);
  virtual ~PIMExecutionProvider();

  AllocatorPtr GetAllocator(int id, OrtMemType mem_type) const override;
  std::vector<std::unique_ptr<ComputeCapability>>
  GetCapability(const onnxruntime::GraphViewer& graph,
                const std::vector<const KernelRegistry*>& /*kernel_registries*/) const override;

  ProviderOptions GetProviderOptions() const override {
    return PIMExecutionProviderInfo::ToProviderOptions(info_);
  }
  std::shared_ptr<KernelRegistry> GetKernelRegistry() const override;
  std::unique_ptr<onnxruntime::IDataTransfer> GetDataTransfer() const override;
  std::vector<NodeIndex> pim_nodes;

  // Status OnRunStart() override;
Status RegisterLut() override;
Bfloat16* ReturnLut(int funct_id) const override;

void ReadFile(const char * fname, Bfloat16* array, size_t length);
bool FileExistanceCheck(const std::string& funct, std::vector<std::string>& check_tables);
PathString MakeLutFileName(const std::string& funct);

bool IsNodeSupportedByPim(
    const onnxruntime::Node& node,
    const onnxruntime::KernelRegistry& registry);

 private:
  PIMExecutionProviderInfo info_;  
  AllocatorPtr allocator_;
  
  // Bfloat16* erf_lut;
  // Bfloat16* sqrt_lut;
  // Bfloat16* relu_lut;
  // Bfloat16* neg_lut;
  // Bfloat16* abs_lut;
  // Bfloat16* log_lut;
  // Bfloat16* sigmoid_lut;
  // Bfloat16* tanh_lut;

  Bfloat16* lut_ptr_arr[LUT_OPS_NUM];
  // Bfloat16** lut_ptr_arr;

};

}  // namespace onnxruntime


