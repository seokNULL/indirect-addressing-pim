// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "core/framework/op_kernel.h"
#include "core/common/common.h"
#include "core/providers/pim/helper/pim_interface.h"
#include "core/providers/pim/helper/aten/convert_numeric.h"

namespace onnxruntime {
namespace pim {
template <typename T>
class Gemm : public OpKernel {
 public:
  Gemm(const OpKernelInfo& info) : OpKernel(info) {
    pim_interface = new PIMInterface();
    int64_t temp;
    ORT_ENFORCE(info.GetAttr<int64_t>("transA", &temp).IsOK());
    is_trans_A_ = temp == 0 ? false : true;

    ORT_ENFORCE(info.GetAttr<int64_t>("transB", &temp).IsOK());
    is_trans_B_ = temp == 0 ? false : true;

    ORT_ENFORCE(info.GetAttr<float>("alpha", &alpha_).IsOK());
    ORT_ENFORCE(info.GetAttr<float>("beta", &beta_).IsOK());
  }

  Status Compute(OpKernelContext* context) const override;

 PIMInterface* pim_interface;
 private:
  bool is_trans_A_ = false;
  bool is_trans_B_ = false;
  float alpha_;
  float beta_;

 protected:
  TensorShape b_shape_;
  BufferUniquePtr packed_b_;

};

void wgt_align_chunk(const Bfloat16 *src, Bfloat16 *dst, int row_dim, int col_dim) {
    int col_chunk_num = 0;

    if (col_dim % CHUNK != 0) {
        col_chunk_num = CHUNK * (col_dim / CHUNK + 1) / CHUNK;
    } else {
      col_chunk_num = col_dim / CHUNK;
    }
    
    int dest_idx = 0;
    if (col_dim > CHUNK) {
        for (int i = 0; i < col_chunk_num; i++) {
            for (int j = 0; j < row_dim; j++) {
                if (i < col_chunk_num - 1) {
                    for (int k = 0; k < CHUNK; k++) {
                        dst[dest_idx] = (src[(i*CHUNK)+(j*col_dim)+k]);
                        // std::cout << "dest_idx: "<< dest_idx << "\tsrc_index: " << (i*CHUNK)+(j*col_dim)+k << std::endl;
                        dest_idx++;
                    }
                }
                // LAST COL NUM
                else {
                    for (int k = 0; k < CHUNK; k++) {
                        if (i * CHUNK + k < col_dim) {
                            dst[dest_idx] = (src[(i*CHUNK)+(j*col_dim)+k]);
                            // std::cout << "dest_idx: "<< dest_idx << "\tsrc_index: " << (i*CHUNK)+(j*col_dim)+k << std::endl;
                        } else {
                            // printf("ZERO padding");
                            dst[dest_idx] = (0);
                        }
                        dest_idx++;
                    }
                }
            }
        }

        // std::cout << "dest_idx: " << dest_idx << std::endl;
        
    } else if (col_dim == CHUNK) {
        for (int i = 0; i < row_dim * col_dim; i++) {
            dst[i] = (src[i]);
        }
    } else {
        printf("NOT SUPPORTED, NEED ALIGNMENT");
    }
}

}  // namespace pim
}  // namespace onnxruntime
