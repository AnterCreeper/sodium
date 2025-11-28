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
`define DEBUG_RESULT    "dump_data.bin"

`define DEBUG_FINISH    0
`define MAX_RUN_CYCLES  0

`define DEBUG_CMD_HALT  16'h1

`include "define_cpu.v"
`include "define_reg.v"

`define PACK_ARRAY(PK_WIDTH, PK_LEN, PK_DEST, PK_SRC) \
genvar pk_idx; \
generate \
for(pk_idx = 0; pk_idx < (PK_LEN); pk_idx = pk_idx + 1) \
begin \
    assign PK_DEST[pk_idx*(PK_WIDTH)+:(PK_WIDTH)] = PK_SRC[pk_idx][((PK_WIDTH)-1):0]; \
end \
endgenerate

`define UNPK_ARRAY(PK_WIDTH, PK_LEN, PK_DEST, PK_SRC) \
genvar unpk_idx; \
generate \
for(unpk_idx = 0; unpk_idx < (PK_LEN); unpk_idx = unpk_idx + 1) \
begin \
    assign PK_DEST[unpk_idx][(PK_WIDTH)-1:0] = PK_SRC[unpk_idx*(PK_WIDTH)+:(PK_WIDTH)]; \
end \
endgenerate
