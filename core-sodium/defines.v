`timescale 1ns/1ps

// HAL
`include "hal/define_hal.v"

// Core
`include "define_cpu.v"

// MGMT AS(Address Space)
`include "define_reg.v"

// Macros
`include "define_func.v"

// SIM
`ifndef SYSCLK_FREQ
`define SYSCLK_FREQ     'd200   //System Clock 200 MHz
`endif
`define SIM_CYC	        5       //200MHz
`define SIM_HALF_CYC    2.5
`define SIM_QUAT_CYC    1.25
`define SIM_RELEASE     250

// DEBUG
//`define DEBUG
`define DEBUG_RAMFILE   "ram.bin"
//`define DEBUG_SEPERATE_DATA
`define DEBUG_DATA_TXT  "test_data.txt"
//`define DEBUG_DUMP
`define DEBUG_DUMP_LO   0
`define DEBUG_DUMP_HI   1024    //Memory Dump Range [LO, HI)
`define DEBUG_RESULT    "dump_data.bin"
`define DEBUG_FINISH    0
`define MAX_RUN_CYCLES  0
`define DEBUG_CMD_HALT  16'h1

// USB
`define USB_VENDORID    16'h1D50
`define USB_PRODUCTID   16'h6130
`define USB_BULK_SIZE   'd8
`ifndef USB_BIT_SAMPLES
`define USB_BIT_SAMPLES 'd5     //USB Clock 5*12 MHz
`endif
