#include "stdio.h"

extern int number[];

void qsort(int *data, int start, int end) {
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
    ee_printf(str);
    for(int i = 0; i < 512; i++)
        ee_printf("%d ", number[i]);
    ee_printf("\n");
}

int main() {
    ee_printf("Sodium Qsort Demo:\n");
    print_number("input:");
    qsort(number, 0, 511);
    print_number("output:");
    debug_flush();
    debug_stop();
    return 0;
}
