#!/bin/bash
# Run element-wise addition on CPU with iteration 5 and validation
./elewise 0 256 256 0 -n 5 -v

# Run element-wise multiplication on PIM with iteration 5 and validation
./elewise 1 256 256 2 -n 5 -v

