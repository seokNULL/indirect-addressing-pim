#!/bin/bash
# Run generic matrix-multiplication on CPU with iteration 5 and validation
./gemm 0 -n 5 -v

# Run generic matrix-multiplication on PIM(Silent) with iteration 5 and validation
./gemm 1 -n 5 -v


