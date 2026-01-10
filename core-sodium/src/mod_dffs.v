`include "defines.v"

module dffs_sp
#(
    parameter SIZE = 0,     //orders of word
    parameter WLEN = 0      //length of word
)(
    input               CLK,

    input               CEN,
    input               WEN,
    input[SIZE-1:0]     A,
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

module dffs_dp_mask
#(
    parameter SIZE = 0,     //orders of word counts
    parameter WLEN = 0,     //length of word
    parameter STEP = 0      //partition orders of word
)(
    input CLK,

    input                       CENA,
    input[(2**STEP)-1:0]        WENA,
    input[SIZE-1:0]             AA,
    input[WLEN-1:0]             DA,
    output[WLEN-1:0]            QA,

    input[(2**SIZE)-1:0]        WENB,
    input[WLEN*(2**SIZE)-1:0]   DB,
    input[(2**SIZE)-1:0]        MASK,
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
    if (!CENA) P <= AA;
    for(i = 0; i < 2**SIZE; i = i + 1)
    begin
        if (!WENB[i] && MASK) MEM[i] <= _DB[i];
        else
        for(j = 0; j < 2**STEP; j = j + 1)
        MEM[i][j*WIDTH+:WIDTH] <= (AA == i) && !CENA && !WENA[j] ? DA[j*WIDTH+:WIDTH] : MEM[i][j*WIDTH+:WIDTH];
    end
end

endmodule

module dffs_dp_async
#(
    parameter SIZE = 0,     //orders of word counts
    parameter WLEN = 0,     //length of word
    parameter STEP = 0      //partition orders of word
)(
    input CLK,

    input                   CENA,
    input[(2**STEP)-1:0]    WENA,
    input[SIZE-1:0]         AA,
    input[WLEN-1:0]         DA,

    input[SIZE-1:0]         AB,
    output[WLEN-1:0]        QB
);

localparam WIDTH = `MIN(2**($clog2(WLEN)-STEP), WLEN);

reg[WLEN-1:0] MEM[(2**SIZE)-1:0];
assign QB =   MEM[AB];

integer i, j;
always @(posedge CLK)
begin
    for(i = 0; i < 2**SIZE; i = i + 1)
    begin
        for(j = 0; j < 2**STEP; j = j + 1)
        MEM[i][j*WIDTH+:WIDTH] <= (AA == i) && !CENA && !WENA[j] ? DA[j*WIDTH+:WIDTH] : MEM[i][j*WIDTH+:WIDTH];
    end
end

endmodule

module dffs_sp_reset
#(
    parameter WLEN = 0      //length of word
)(
    input CLK,
    input RST,
    input                   CENA,
    input[WLEN-1:0]         WENA,
    input[WLEN-1:0]         DA,
    input                   CENB,
    input[WLEN-1:0]         WENB,
    output reg[WLEN-1:0]    Q
);

wire[WLEN-1:0] RSTB = {WLEN{CENB}} | WENB;

integer i;
always @(posedge CLK or negedge RST)
begin
    for(i = 0; i < WLEN; i = i + 1)
    begin
        if(!RST) Q[i] <= 0;
        else     Q[i] <= RSTB[i] && (!WENA[i] && !CENA ? DA[i] : Q[i]);
    end
end

endmodule
