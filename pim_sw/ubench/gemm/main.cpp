#include <getopt.h>
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

static bool print_matrix = false;
static bool validation = false;
static size_t device = 0;
static size_t M = 16;
static size_t N = 256;
static size_t K = 256;
static size_t num_iterations = 1;

static char matmul_type_string[6][64] = {
    "CPU (sequential)", "PIM",
};

static void print_help(const char *prog_name) {
  printf("Usage: %s [-pvh] [-n num_iterations] device M N K\n", prog_name);
  printf("Options:\n");
  printf("     -p : print matrix. (default: off)\n");
  printf("     -v : validate matmul. (default: off)\n");
  printf("     -h : print this page.\n");
  printf("     -n : number of iterations (default: 1)\n");
  printf("      device : type of matrix multiplication (default: 0)\n");
  printf("            0 : CPU (sequential)\n");
  printf("            1 : PIM (Silent-PIM)\n");
  printf("      M : number of rows of matrix A and C. (default: 16)\n");
  printf("      N : number of columns of matrix B and C. (default: 256)\n");
  printf(
      "      K : number of columns of matrix A and rows of B. (default: 256)\n");
}

static void parse_opt(int argc, char **argv) {
  int c;
  while ((c = getopt(argc, argv, "pvht:n:m:")) != -1) {
    switch (c) {
      case 'p': print_matrix = true; break;
      case 'v': validation = true; break;
      case 'n': num_iterations = atoi(optarg); break;
      case 'h':
      default: print_help(argv[0]); exit(0);
    }
  }
  for (int i = optind, j = 0; i < argc; ++i, ++j) {
    switch (j) {
      case 0: device = (size_t) atoi(argv[i]); break;
      case 1: M = (size_t) atoi(argv[i]); break;
      case 2: N = (size_t) atoi(argv[i]); break;
      case 3: K = (size_t) atoi(argv[i]); break;
      default: break;
    }
  }

  printf("============= Matrix Multiplication Benchmark =============\n");
  printf("- Matmul Type: %s\n", matmul_type_string[device]);
  printf("- Problem size: M = %lu, N = %lu, K = %lu\n", M, N, K);
  printf("- A = (%lu) x (%lu), B = (%lu) x (%lu), C = (%lu) x (%lu)\n", M, K, K, N, M, N);
  printf("- Number of iterations: %lu\n", num_iterations);
  printf("- Print matrix: %s\n", print_matrix ? "on" : "off");
  printf("- Validation: %s\n", validation ? "on" : "off");
}

void gemm_cpu(float *A, float *B, float * bias, float *C, size_t M, size_t N, size_t K) {
  // Naive CPU matrix multiplication
  for (int i = 0; i < M; ++i) {
    for (int k = 0; k < K; ++k) {
      for (int j = 0; j < N; ++j) {
        C[i * N + j] += A[i * K + k] * B[k * N + j];
      }
    }
  }

  for (int i = 0; i < M; ++i) {
    for (int j = 0; j < N; ++j) {
        C[i * N + j] += C[i * N + j] * bias[i * N + j];
    }
  } 
}

void gemm_pim(short *A, short *B, short *bias, short *C, pim_args *pim_code, size_t M, size_t N, size_t K) {
  pim_code->srcA_va = (uint64_t)&A[0];
  pim_code->srcB_va = (uint64_t)&B[0];
  pim_code->bias_va = (uint64_t)&bias[0];
  pim_code->dstC_va = (uint64_t)&C[0];
  pim_code->p_size  = M;
  pim_code->q_size  = K;
  pim_code->r_size  = N;  
  gemm(pim_code);
}



int main(int argc, char **argv) {
  parse_opt(argc, argv);
  fflush(stdout);

  /* Allocate and initialize matrices on CPU and PIM*/
    int p_size = M;
    int q_size = K;
    int r_size = N;

    int srcA_size = p_size * q_size;
    int srcB_size = q_size * r_size;
    int dstC_size = p_size * r_size;

    if ((init_pim_drv()) < 0) {
        perror("PIM DMA drvier open");
        exit(-1);
    }

    float *srcA = (float *)(mmap(NULL, srcA_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *srcB = (float *)(mmap(NULL, srcB_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *srcbias = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));   
    float *dstC = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    float *C_ans = (float *)(mmap(NULL, dstC_size*sizeof(float), PROT_WRITE | PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));

    short *srcA_pim = (short *)pim_malloc(srcA_size*sizeof(short));
    short *srcB_pim = (short *)pim_malloc(srcB_size*sizeof(short));
    short *srcbias_pim = (short *)pim_malloc(dstC_size*sizeof(short));
    short *dstC_pim = (short *)pim_malloc(dstC_size*sizeof(short));

    pim_args *pim_code;
    int size = sizeof(pim_args);
    pim_code = (pim_args *)malloc(1024*1024*size);

    if (srcA_pim == MAP_FAILED) {
        printf("PL srcA call failure.\n");
        return -1;
    }
    if (srcB_pim == MAP_FAILED) {
        printf("PL srcB call failure.\n");
        return -1;
    }
    if (srcbias_pim == MAP_FAILED) {
        printf("PL srcbias call failure.\n");
        return -1;
    }    
    if (dstC_pim == MAP_FAILED) {
        printf("PL dstC call failure.\n");
        return -1;
    }
    zero_mat(srcA, p_size, q_size);
    zero_mat(srcB, q_size, r_size);
    zero_mat(srcbias, p_size, r_size);
    zero_mat(dstC, p_size, r_size);
    
    zero_mat(srcA_pim, p_size, q_size);
    zero_mat(srcB_pim, q_size, r_size);
    zero_mat(srcbias_pim, p_size, r_size);
    zero_mat(dstC_pim, p_size, r_size);
    
    srand((unsigned int)time(NULL));  // For reset random seed
    rand_mat(srcA, p_size, q_size);
    rand_mat(srcB, q_size, r_size);
    rand_mat(srcbias, p_size, r_size);

    //for validation
    zero_mat(C_ans, p_size, q_size);
    gemm_cpu(srcA, srcB, srcbias, C_ans, p_size, r_size, q_size);
    
  /* Initialize Matrix Multiplication */
    copy_mat_input(srcA, srcA_pim, p_size, q_size);
    copy_mat_input(srcB, srcB_pim, q_size, r_size);
    copy_mat_input(srcbias, srcbias_pim, p_size, r_size);

    switch (device) {
      case 0: break;
      case 1: srcB_pim = matmul_pim_initialize(srcB_pim, q_size, r_size); break;
      // case 2: matmul_decoupled_pim_initialize(srcA, srcB, srcA_pim, srcB_pim, p_size, q_size, r_size); break;
    }


  /* Run matrix multiplication for num_iterations */
  printf("\n--------------------- Run Benchmark -----------------------\n");

  double elapsed_time_sum = 0;
  for (size_t i = 0; i < num_iterations; ++i) {
    printf("[iter %lu] ", i);
    fflush(stdout);

  // We assume all data which PIM executed is prepared before launching PIM kernel.
  // For example, when PIM design is implemented in system-memory,
  // all data movement cost can be removed.
    double elapsed_time_iter = -get_current_time();
    switch (device) {
      case 0: gemm_cpu(srcA, srcB, srcbias, dstC, p_size, r_size, q_size); break;
      case 1: gemm_pim(srcA_pim, srcB_pim, srcbias_pim, dstC_pim, pim_code, p_size, r_size, q_size); break;
      // case 2: matmul_decoupled_pim(srcA_pim, srcB_pim, dstC_pim, pim_code, p_size, r_size, q_size); break;
    }
    elapsed_time_iter += get_current_time();

    // printf("%.4f ms\n", elapsed_time_iter*1000);
    printf("%.4f ns\n", elapsed_time_iter*1000000000);
    elapsed_time_sum += elapsed_time_iter;
  }


  /* Print performance results */
  double elapsed_time_avg = elapsed_time_sum / num_iterations;
  printf("\n-------------------- Benchmark Summary --------------------\n");
  // printf("Avg. time        : %.4f ms\n", elapsed_time_avg*1000);
  printf("Avg. time        : %.4f ns\n", elapsed_time_avg*1000000000);
  printf("Avg. performance : %.1f GFLOPs\n",
         2.0 * M * N * K / elapsed_time_avg / 1e9);


    /* Finalize matrix multiplication */
  switch (device) {
    case 0: matmul_cpu_finalize(p_size, r_size, q_size); break;
    case 1: matmul_pim_finalize(srcA_pim, srcB_pim, dstC_pim, p_size, r_size, q_size); break;
    // case 2: matmul_decoupled_pim_finalize(srcA_pim, srcB_pim, dstC_pim, p_size, r_size, q_size); break;
  }

  if (print_matrix) {
    printf("\n---------------------- Print Matrix -----------------------\n");
    // printf("MATRIX A:\n");
    // print_mat(srcA, M, N);
    // printf("MATRIX B:\n");
    // print_mat(srcB, M, N);
    // printf("MATRIX C:\n");
    // print_mat(dstC, M, N); 
    printf("MATRIX C_ans:\n");
    print_mat(C_ans, M, N); 
    printf("MATRIX PIM:\n");
    for (int i = 0; i < dstC_size; ++i) { printf("%+.3f ", short_to_float(dstC_pim[i])); }
    printf("\n");
  }

  if (validation) {
    printf("\n----------------------- Validation ------------------------\n");
    switch (device) {
      case 0: printf("Validation Result: VALID\n"); break;      
      case 1: check_mat_mul(dstC_pim, C_ans, p_size, r_size, q_size); break;
      // case 2: check_mat_mul(dstC_pim, C_ans, p_size, r_size, q_size); break;
    }  
  }

  printf("\n===========================================================\n");

  munmap(srcA, srcA_size*sizeof(float));
  munmap(srcB, srcB_size*sizeof(float));
  munmap(srcbias, dstC_size*sizeof(float));
  munmap(dstC, dstC_size*sizeof(float));
  munmap(C_ans, dstC_size*sizeof(float));

  free(pim_code);
  pim_free(srcA_pim);
  pim_free(srcB_pim);
  pim_free(srcbias_pim);
  pim_free(dstC_pim);

  return 0;
}
