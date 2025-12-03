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

static void debug_flush() {
    #pragma clang loop unroll(disable)
    for(int i = 0; i < 512; i = i + 16) dcache_flush((void*)i);
    return;
}

static void debug_stop() {
    int cmd = 0x1;
    __asm__ volatile("wcsr\t0x1e, %0" : : "r"(cmd));
}

static void debug_putchar(unsigned char c) {
    __asm__ volatile("wcsr\t0x1f, %0" : : "r"(c));
}

void *memset(void *str, int c, size_t n);
void *memcpy(void *dest, const void * src, size_t n);
void qsort(int *data, int start, int end);

#define __bf_shf(x) (__builtin_ffs(x) - 1)

#define XLEN 16
#define GENMASK(h, l) (((~0U) - (1U << (l)) + 1) & (~0U >> (XLEN - 1 - (h))))

#define FIELD_PREP(_mask, _val)						\
(((typeof(_mask))(_val) << __bf_shf(_mask)) & (_mask))

#define FIELD_GET(_mask, _reg)						\
((typeof(_mask))(((_reg) & (_mask)) >> __bf_shf(_mask)))

#define FIELD_MAX(_mask)						\
((typeof(_mask))((_mask) >> __bf_shf(_mask)))

#define FIELD_FIT(_mask, _val)						\
!((((typeof(_mask))_val) << __bf_shf(_mask)) & ~(_mask))

#define FIELD_MODIFY(_mask, _reg_p, _val)						\
({										\
    *(_reg_p) &= ~(_mask);							\
    *(_reg_p) |= (((typeof(_mask))(_val) << __bf_shf(_mask)) & (_mask));	\
})

static unsigned int __bytereplica16(unsigned char c) {
    unsigned int result;
    __asm__ volatile("pack\t%0, %1, %1, 8" : "=r"(result) : "r"(c));
    return result;
}

#define __bytereplica32(c)  (((unsigned long)__bytereplica16(c) << 16) | __bytereplica16(c))
#define __aligned(p)        (((size_t)p & 0xf) == 0)

#endif
