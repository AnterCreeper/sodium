`include "defines.v"

module icache_mem(
    input CLKA,
    input CLKB,
    input CENA,
    input CENB,
    input[29:0]  AA,
    output[31:0] QA,
    input[29:0]  AB,
    input[31:0]  DB
);

reg[31:0] mem[16383:0];
`ifdef DEBUG
integer fd;
initial
begin
    fd = $fopen(`DEBUG_RAMFILE, "rb");
    $fread(mem, fd);
end
`endif

reg[13:0] adr;
initial adr = 0;

wire[31:0] QA_BE;
assign QA_BE = mem[adr];
assign QA = {QA_BE[7:0], QA_BE[15:8], QA_BE[23:16], QA_BE[31:24]};

always @(posedge CLKA)
begin
    if(!CENA) adr <= AA;
end
always @(posedge CLKB)
begin
    if(!CENB) mem[AB] <= DB;
end

endmodule

module mp_icache(
    input        sys_clk,
    input        sys_setn,

    input        icache_ack,
    input[29:0]  icache_addr,
    output reg   icache_vld,
    output[31:0] icache_data
);

initial begin
icache_vld = 1;
/*
#250;
#2.5;
#1000 icache_vld = 0;
#150;
#1000 icache_vld = 1;
*/
end

icache_mem mem(
    .CLKA(sys_clk),
    .CLKB(sys_clk),
    .CENA(~icache_ack),
    .CENB(1'b1),
    .AA(icache_addr),
    .QA(icache_data),
    .AB(30'b0),
    .DB(32'b0)
);

endmodule
