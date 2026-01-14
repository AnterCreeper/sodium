#!/bin/bash
./coegen-x86_64 -f asm -s number input.bin > data.S
clang -o qsort -DDEBUG ./data.S ./main.c
rm data.S
