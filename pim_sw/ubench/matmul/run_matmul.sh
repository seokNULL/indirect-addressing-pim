#!/bin/bash
# Run matrix-multiplication on CPU with iteration 5 and validation
./matmul 0 -n 5 -v

# Run matrix-multiplication on PIM(Silent) with iteration 5 and validation
./matmul 1 -n 5 -v

# Run matrix-multiplication on PIM(Decoupled w\ tiling) with iteration 5 and validation
./matmul 2 -n 5 -v

