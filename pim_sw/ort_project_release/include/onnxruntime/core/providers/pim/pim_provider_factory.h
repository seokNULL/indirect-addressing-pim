#include "onnxruntime_c_api.h"

#ifdef __cplusplus
extern "C" {
#endif

ORT_API_STATUS(OrtSessionOptionsAppendExecutionProvider_PIM, _In_ OrtSessionOptions* options, int device_id, size_t hip_mem_limit);

#ifdef __cplusplus
}
#endif

