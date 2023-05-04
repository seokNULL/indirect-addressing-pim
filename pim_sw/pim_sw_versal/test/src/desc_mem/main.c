#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <pim.h>

struct timespec start_t, end_t;
uint64_t diff_time;
#define BILLION 1000000000L

char *ushortToBinary(uint8_t i, int num_page) {
  static char s[8 + 1] = { '0', };
  int count = 8;

  do { s[--count] = '0' + (char) (i & 1);
       i = i >> 1;
  } while (count);

  return s;
}

char *num_to_bin(int num) {
    char *tmp = (char *)malloc(sizeof(char) * num);

    for (size_t i = 0; i < num; i++) {
        tmp[i] = '1';
    }
    return tmp;
}

/* Test code main */
int main()
{
    
    init_desc_mem();
    return 0;
}
