#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h> 
#include <stdint.h>

#include <sys/ioctl.h>
#include <stdbool.h>

#include <pim.h>
#include "matmul.h"
#include "util.h"

void pim_align(short *src, short *dst, int row_dim, int col_dim) {
    int CHUNK = 256;
    int col_chunk_num = 0;
    if (col_dim % 256 != 0) {
        col_chunk_num = 256 * (col_dim / 256 + 1) / CHUNK;
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
                        dest_idx++;
                    }
                }
                // LAST COL NUM
                else {
                    for (int k = 0; k < CHUNK; k++) {
                        if (i * CHUNK + k < col_dim) {
                            dst[dest_idx] = (src[(i*CHUNK)+(j*col_dim)+k]);
                        } else {
                            dst[dest_idx] = (0);
                        }
                        dest_idx++;
                    }
                }
            }
        }
    } else if (col_dim == CHUNK) {
        for (int i = 0; i < row_dim * col_dim; i++) {
            dst[i] = (src[i]);
        }
    } else {
        printf("NOT SUPPORTED, NEED ALIGNMENT");
    }
}

short* matmul_pim_initialize(short *srcB_pim, size_t row_size, size_t col_size) {
    bool need_align = (col_size>256);
    short *srcB_pim_aligned = (short *)pim_malloc(row_size * col_size * sizeof(short));
    zero_mat(srcB_pim_aligned, row_size, col_size);
    
    pim_align(srcB_pim, srcB_pim_aligned, row_size, col_size);
    if (need_align) return srcB_pim_aligned;
    else            return srcB_pim;
}

void matmul_pim_finalize(short *A, short *B, short *C, size_t M, size_t N, size_t K) {
  // Nothing to do
  return;
}