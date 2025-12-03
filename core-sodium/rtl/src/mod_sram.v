`include "defines.v"

/*
 *  SRAM Simulation Model
 *  Don't use for synthesis, use Memory Compiler Instead!
 */

module sram_sp_mask
#(
    parameter SIZE = 0,     //orders of word counts
    parameter WLEN = 0,     //length of word
    parameter STEP = 0      //partition orders of word
)(
    input CLK,

    input                CEN,
    input[(2**STEP)-1:0] WEN,
    input[SIZE-1:0]      A,
    input[WLEN-1:0]      D,
    output[WLEN-1:0]     Q
);

localparam WIDTH = `MIN(2**($clog2(WLEN)-STEP), WLEN);

reg[WLEN-1:0] MEM[(2**SIZE)-1:0];
reg[SIZE-1:0] P;
assign Q =    MEM[P];

integer i, j;
always @(posedge CLK)
begin
    if (!CEN)
    begin
        P <= A;
        for(j = 0; j < 2**STEP; j = j + 1)
        MEM[A][j*WIDTH+:WIDTH] <= !WEN[j] ? D[j*WIDTH+:WIDTH] : MEM[A][j*WIDTH+:WIDTH];
    end
end

endmodule

module sram_sdp
#(
    parameter SIZE = 0,     //orders of word counts
    parameter WLEN = 0      //length of word
)(
    input                CLK,
    input                CENA,
    input[SIZE-1:0]      AA,
    output[WLEN-1:0]     QA,
    input                CENB,
    input[SIZE-1:0]      AB,
    input[WLEN-1:0]      DB
);

reg[WLEN-1:0] MEM[(2**SIZE)-1:0];
reg[SIZE-1:0] P;
assign QA =   MEM[P];

always @(posedge CLK)
begin
    if (!CENA) P <= AA;
    if (!CENB) MEM[AB] <= DB;
end

endmodule
