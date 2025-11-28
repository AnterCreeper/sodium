`include "defines.v"

`define MIN(a, b) ((a)<(b)?(a):(b))

module dffs_single_port
#(
    parameter SIZE = 0,     //orders of word
    parameter WLEN = 0      //length of word
)(
    input               CLK,
    input               CEN,

    input[SIZE-1:0]     A,
    input               WEN,
    input[WLEN-1:0]     D,
    output[WLEN-1:0]    Q,

    output[WLEN*(2**SIZE)-1:0] DFF
);

reg[WLEN-1:0] MEM[(2**SIZE)-1:0];
`PACK_ARRAY(WLEN, 2**SIZE, DFF, MEM)

reg[SIZE-1:0] P;
assign Q =    MEM[P];

always @(posedge CLK)
begin
    if (!CEN)
    begin
        P <= A;
        MEM[A] <= !WEN ? D : MEM[A];
    end
end

endmodule

module dffs_dual_port_mask
#(
    parameter SIZE = 0,     //orders of word counts
    parameter WLEN = 0,     //length of word
    parameter STEP = 0      //partition orders of word
)(
    input               CLK,
    input               CEN,

    input[SIZE-1:0]     AA,
    input[STEP:0]       WENA,
    input[WLEN-1:0]     DA,
    output[WLEN-1:0]    QA,

    input[(2**SIZE)-1:0]        WENB,
    input[(2**SIZE)-1:0]        MASK,
    input[WLEN*(2**SIZE)-1:0]   DB,
    output[WLEN*(2**SIZE)-1:0]  DFF
);

localparam WIDTH = `MIN(2**($clog2(WLEN)-STEP), WLEN);

reg[WLEN-1:0] MEM[(2**SIZE)-1:0];
wire[WLEN-1:0] _DB[(2**SIZE)-1:0];
`PACK_ARRAY(WLEN, 2**SIZE, DFF, MEM)
`UNPK_ARRAY(WLEN, 2**SIZE, _DB, DB)

reg[SIZE-1:0] P;
assign QA =   MEM[P];

integer i, j;
always @(posedge CLK)
begin
    if (!CEN) P <= AA;
    for(i = 0; i < 2**SIZE; i = i + 1)
    begin
        if (!WENB[i] && MASK) MEM[i] <= _DB[i];
        else
        for(j = 0; j < STEP; j = j + 1)
        MEM[i][j*WIDTH+:WIDTH] <= (AA == i) && !CEN && !WENA[j] ? DA[j*WIDTH+:WIDTH] : MEM[i][j*WIDTH+:WIDTH];
    end
end

endmodule
