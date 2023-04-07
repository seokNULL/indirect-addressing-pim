#pragma once
#include <string>
double get_current_time();

void rand_mat(float *m, int R, int S);
void zero_mat(float *m, int R, int S);
void zero_mat(short *m, int R, int S);

void print_mat(float *m, int M, int N);
void check_elewise(short* result_pim, float *C_ans, int M, int N, int opcode);
void copy_mat_input(float *src, short *dst, int size);
void copy_mat_result(short *src, float *dst, int size);
