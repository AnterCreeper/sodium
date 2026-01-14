#ifdef DEBUG
#include <stdio.h>
#include <stdint.h>
#else
#include "stdio.h"
#include "stdint.h"
#endif

extern int16_t number[];

#ifndef DEBUG
#define printf(...) ee_printf(__VA_ARGS__)
#endif

void qsort(int16_t *data, int start, int end) {
    if(end > start) {
        int i = start, j = end, key = data[start];
        while(i < j) {
            for (;i < j && key <= data[j]; j--);
            data[i] = data[j];
            for (;i < j && key >= data[i]; i++);
            data[j] = data[i];
        }
        data[i] = key;
        qsort(data, start, i - 1);
        qsort(data, i + 1, end);
    }
    return;
}

void print_number(const char* str) {
    printf("%s", str);
    for(int i = 0; i < 512; i++)
        printf("%d ", number[i]);
    printf("\n");
}

int main() {
    printf("Sodium Qsort Demo:\n");
    print_number("input:");
    qsort(number, 0, 511);
    print_number("output:");
#ifndef DEBUG
    debug_flush();
    debug_stop();
#endif
    return 0;
}
