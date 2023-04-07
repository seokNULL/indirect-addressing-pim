#include "util.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <limits.h>
#include <iostream>
#include <math.h>
#include <bitset>
#include <sys/mman.h>

double get_current_time() {
  struct timespec tv;
  clock_gettime(CLOCK_MONOTONIC, &tv);
  return tv.tv_sec + tv.tv_nsec * 1e-9;
}


void rand_mat(float *m, int R, int S) {
  int N = R * S;
  for (int j = 0; j < N; j++) { m[j] = ((float) rand() / RAND_MAX - 0.5)/10; }
}

void zero_mat(float *m, int R, int S) {
  int N = R * S;
  for(size_t i=0; i<N; i++){
    m[i]=0;
  }
}
void zero_mat(short *m, int R, int S) {
  int N = R * S;
  for(size_t i=0; i<N; i++){
    m[i]=0;
  }
}
void print_mat(float *m, int M, int N) {
  for (int i = 0; i < M; ++i) {
    for (int j = 0; j < N; ++j) { printf("%+.3f ", m[i * N + j]); }
    printf("\n");
  }
}

void check_mat_mul(short* result_pim, float *C_ans, int M, int N, int K) {
  bool is_valid = true;
  int cnt = 0, thr = 10;
  float eps = 1e-1;
  for (int i = 0; i < M; ++i) {
    for (int j = 0; j < N; ++j) {
      float c = short_to_float(result_pim[i * N + j]);
      float c_ans = C_ans[i * N + j];
      if (fabsf(c - c_ans) > eps &&
          (c_ans == 0 || fabsf((c - c_ans) / c_ans) > eps)) {
        ++cnt;
        if (cnt <= thr)
          printf("C[%d][%d] : correct_value = %f, your_value = %f\n", i, j,
                 c_ans, c);
        if (cnt == thr + 1)
          printf("Too many error, only first %d values are printed.\n", thr);
        is_valid = false;
      }
    }
  }

  if (is_valid) {
    printf("Validation Result: VALID\n");
  } else {
    printf("Validation Result: INVALID\n");
  }
}

// Convert the 32-bit binary encoding into hexadecimal
int Binary2Hex( std::string Binary )
{
  std::bitset<32> set(Binary);      
  int hex = set.to_ulong();
  return hex;
}
 
// Convert the 32-bit binary into the decimal
float GetFloat( std::string Binary )
{
  int HexNumber = Binary2Hex( Binary );
  bool negative  = !!(HexNumber & 0x80000000);
  int  exponent  =   (HexNumber & 0x7f800000) >> 23;    
  int sign = negative ? -1 : 1;

  // Subtract 127 from the exponent
  exponent -= 127;
  // Convert the mantissa into decimal using the
  // last 23 bits
  int power = -1;
  float total = 0.0;
  for ( int i = 0; i < 23; i++ )
  {
      int c = Binary[ i + 9 ] - '0';
      total += (float) c * (float) pow( 2.0, power );
      power--;
  }
  total += 1.0;
  float value = sign * (float) pow( 2.0, exponent ) * total;
  return value;
}
 
// Get 32-bit IEEE 754 format of the decimal value
std::string GetBinary( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string mystring = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  return mystring;
}

// Get 32-bit IEEE 754 format of the decimal value
std::string convert_16bit( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string str = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  str = str.substr(0,16);
  return str;
}

short float_to_short( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string str = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  str = str.substr(0,16);
  return std::stoi(str, nullptr, 2);
}

float short_to_float (short value)
{
  union
  {
    short input;
    int   output;
  }data;
  data.input = value;
  std::bitset<sizeof(short) * CHAR_BIT>   bits(data.output);
  std::string mystring = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  //std::cout<<mystring<<std::endl;
  mystring.append("0000000000000000");
  //std::cout<<mystring<<std::endl;

  return GetFloat(mystring);
  //std::cout<<test<<std::endl;  
}


void copy_mat_input(float *src, short *dst, int row, int col){
  for(size_t i = 0; i < row * col; i++){
    float tmp  = src[i];
    // float tmp  = 3.5;
    short tmp0 = float_to_short(tmp);
    dst[i] = tmp0;
  }
}

void copy_mat_result(short *src, float *dst, int size){
  for(size_t i=0; i<size; i++){
    short tmp  = src[i];
    // float tmp  = 3.5;
    float tmp0 = short_to_float(tmp);
    dst[i] = tmp0;
  }

  
}

