#include "stdio.h"

void *memset(void *str, int c, size_t n) {
    char *d = str;
    int t = (n + 7) / 8;
    switch (n % 8) {
    case 0 : do { *d++ = c;
    case 7 :      *d++ = c;
    case 6 :      *d++ = c;
    case 5 :      *d++ = c;
    case 4 :      *d++ = c;
    case 3 :      *d++ = c;
    case 2 :      *d++ = c;
    case 1 :      *d++ = c;
    } while (--t > 0);
    }
    return str;
}

void *memcpy(void *dest, const void * src, size_t n) {
    char* pdst = dest;
    const char* psrc = src;
    int i = 0;
    while (i < n) {
        pdst[i] = psrc[i];
        i++;
    }
    return dest;
}
