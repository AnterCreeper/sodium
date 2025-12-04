# Pointer Overflow Compare

### Code
```
int foo(const char *ptr, size_t index) {
    const char *end_ptr = &ptr[index];
    return end_ptr < ptr;
}
```

### Description
By default(-fno-wrapv), Clang has different behavior(against GCC) while comparing two pointers after adding an unsigned offset to the first pointer.  
Clang:  
```
	srli   a0, a1, 31
```
GCC:  
```
	add    a1, a0, a1
	sltu   a0, a1, a0
```

### Reference
\[1\] [https://github.com/llvm/llvm-project/issues/121909](https://github.com/llvm/llvm-project/issues/121909)  
\[2\] [https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82694](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82694)  
