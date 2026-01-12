#!/bin/bash
model=pic
llvmbin=/home/hp/llvm-project/llvm/build/bin
#debug=-DCORE_DEBUG=1
debug=""
opt="-Os"
$llvmbin/clang --target=sodium16 -fPIC $opt -c ./*.c
./coegen-x86_64 -f asm -s number input.bin > data.S
$llvmbin/clang --target=sodium16 -fPIC -c ./data.S
$llvmbin/clang --target=sodium16 -fPIC -c ./crt.S
$llvmbin/ld.lld -T ./link.ld ./*.o
$llvmbin/llvm-objcopy a.out -O binary ./firmware.bin
rm data.S *.o a.out
