`timescale 1ns/1ps

`define SIM_CYC	        5   //200MHz
`define SIM_HALF_CYC    2.5
`define SIM_QUAT_CYC    1.25

`define SIM_RELEASE     250
`define SIM_MEM_DELAY   20  //in cycles, 100ns

`define DEBUG
`define DEBUG_RAMFILE   "ram.bin"
//`define DEBUG_SEPERATE_DATA
`define DEBUG_DATA_TXT  "test_data.txt"
//`define DEBUG_DUMP
//`define DEBUG_DUMP_LO   0
//`define DEBUG_DUMP_HI   1024    //dump range [LO, HI)
`define DEBUG_RESULT    "dump_data.bin"

`define DEBUG_FINISH    0
`define MAX_RUN_CYCLES  0

`define DEBUG_CMD_HALT  16'h1

`include "define_cpu.v"
`include "define_reg.v"

`include "define_func.v"
