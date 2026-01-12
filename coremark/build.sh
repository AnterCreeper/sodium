#!/bin/bash
model=pic
llvmbin=/home/hp/llvm-project/llvm/build/bin
#debug=-DCORE_DEBUG=1
debug=""
opt="-O2"
$llvmbin/clang $debug --target=sodium16 -fPIC $opt -c ./*.c
$llvmbin/clang --target=sodium16 -fPIC -c ./crt.S
$llvmbin/ld.lld -T ./link.ld ./*.o
$llvmbin/llvm-objcopy a.out -O binary ./firmware.bin
rm *.o a.out
