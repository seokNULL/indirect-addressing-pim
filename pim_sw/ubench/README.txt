###############################################################################
######   Simple C/C++ application for testing PIM device functionality   ######
###############################################################################

######   Directory description 
./bias_op 
    source operand A's dimension < source operand B's dimension
    A = 1 x r
    B = q x r
    C = q x r = A +-* B
    API: bias_add(pim_args..), bias_sub(pim_args..), bias_mul(pim_args..)
./elewise
    source operand A's dimension < source operand B's dimension
    A = p x q
    B = p x q
    C = p x q = A +-* B
    API: elewise_add(pim_args..), elewise_sub(pim_args..), elewise_mul(pim_args..)
./gemm
    source operand A x source operand B + source opeand bias = D
    A = p x q
    B = q x r
    bias = p x r
    C = p x r = A x B + bias 
    API: gemm(pim_args..)
./matmul
    source operand A x source operand B = C
    A = p x q
    B = q x r
    C = p x r = A x B
    API: matmul(pim_args..), matmul_tiled(pim_args..)
./memcpy
    Testing DMA functionality
