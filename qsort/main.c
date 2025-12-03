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

static void __attribute__((always_inline)) dcache_flush(void* data) {
    unsigned *ptr = (unsigned *)data;
    __asm__ volatile("dc.flush\t%0" : : "m"(*ptr));
    return;
}

static void debug_stop() {
    int cmd = 0x1;
    __asm__ volatile("wcsr\t0x1e, %0" : : "r"(cmd));
}

int main() {
    qsort((int*)0, 0, 511);
    #pragma clang loop unroll (disable)
    for(int i = 0; i < 512; i = i + 16)
        dcache_flush((int*)i);
    debug_stop();
    return 0;
}
