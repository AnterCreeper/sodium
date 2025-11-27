#include "time.h"
#include "stdio.h"

void *memset(void *str, int c, size_t n) {
    if (!str) return NULL;
    char* ptr = str;
    int i = 0;
    while (i < n)
        ptr[i++] = c;
    return str;
}

void *memcpy(void *dest, const void * src, size_t n) {
    if (!dest) return NULL;
    if (!src) return NULL;
    char* pdst = dest;
    const char* psrc = src;
    int i = 0;
    while (i < n) {
        pdst[i] = psrc[i];
        i++;
    }
    return dest;
}

clock_t clock() {
    unsigned int lo, hi;
    __asm__ volatile("rcsr\t0x14, %0" : "=r"(lo) : );
    __asm__ volatile("rcsr.h\t0x14, %0" : "=r"(hi) : );
    return ((unsigned long)hi << 16) | lo;
}

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
