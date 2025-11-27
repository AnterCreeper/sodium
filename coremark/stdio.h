#ifndef __STDIO_H__
#define __STDIO_H__

#define NULL (void *)0

#define likely(x)      __builtin_expect(!!(x), 1)
#define unlikely(x)    __builtin_expect(!!(x), 0)

#include "stdint.h"
#include <stdarg.h>

static void __attribute__((always_inline)) dcache_invalid(void* data) {
    unsigned *ptr = (unsigned *)data;
    __asm__ volatile("dc.invd\t%0" : : "m"(*ptr));
    return;
}

static void __attribute__((always_inline)) dcache_zero(void* data) {
    unsigned *ptr = (unsigned *)data;
    __asm__ volatile("dc.zero\t%0" : : "m"(*ptr));
    return;
}

static void __attribute__((always_inline)) dcache_clean(void* data) {
    unsigned *ptr = (unsigned *)data;
    __asm__ volatile("dc.clean\t%0" : : "m"(*ptr));
    return;
}

static void __attribute__((always_inline)) dcache_flush(void* data) {
    unsigned *ptr = (unsigned *)data;
    __asm__ volatile("dc.flush\t%0" : : "m"(*ptr));
    return;
}

int ee_printf(const char *fmt, ...);

static void debug(int x) {
    __asm__ volatile("wcsr\tmcr3, %0" : : "r"(x));
}

static void debug_flush() {
    #pragma clang loop unroll(disable)
    for(int i = 0; i < 512; i = i + 16) dcache_flush((void*)i);
    return;
}

void *memset(void *str, int c, size_t n);
void *memcpy(void *dest, const void * src, size_t n);
void qsort(int *data, int start, int end);

#endif
