#pragma once
#include <string>
double get_current_time();

void rand_mat(float *m, int R, int S);
void zero_mat(float *m, int R, int S);
void zero_mat(short *m, int R, int S);
void print_mat(float *m, int M, int N);
void check_mat_mul(short* result_pim, float *C_ans, int M, int N, int K);

int Binary2Hex( std::string Binary );
float GetFloat( std::string Binary );
std::string GetBinary( float value );
std::string convert_16bit( float value );
short float_to_short( float value );
float short_to_float (short value);

void copy_mat_input(float *src, short *dst, int row, int col);
void copy_mat_result(short *src, float *dst, int row, int col);
