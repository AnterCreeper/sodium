`include "defines.v"

module sys_ocm(
    input            sys_clk,
    input            sys_rst,
//Data Path
    input            mem_request,
    output reg       mem_finish,
    output           mem_partial,
    input            mem_rwn,
    input[15:0]      mem_addr,
    input[15:0]      mem_commit,
    input[127:0]     mem_write_data,
    output           mem_replace,
    output[4:0]      mem_replace_set,
    output[6:0]      mem_replace_tag,
    output[127:0]    mem_replace_dat,
//Insn Path
    input            insn_reset,
    input            insn_request,
    output reg       insn_valid,
    input[15:0]      insn_addr,
    output reg[31:0] insn_data
);

//Data
assign mem_partial = 0;
assign mem_replace = mem_finish && mem_rwn;
assign mem_replace_set = mem_addr[8:4];
assign mem_replace_tag = mem_addr[15:9];

always @(posedge sys_clk or posedge sys_rst)
begin
    if(sys_rst) mem_finish <= 0;
    else mem_finish <= !mem_finish && (mem_request || mem_finish);
end

//Insn
always @(posedge sys_clk or posedge insn_reset)
begin
    if(insn_reset) insn_valid <= 0;
    else insn_valid <= insn_valid || insn_request;
end

wire[127:0] mem_insn_dat;

sys_sram sys_sram(
    .CLK(sys_clk),

    .CENA(!mem_request),
    .WENA(mem_rwn),
    .AA(mem_addr[15:4]),
    .DA(mem_write_data),
    .QA(mem_replace_dat),

    .CENB(!insn_request),
    .WENB(1'b1),    //Read-only
    .AB(insn_addr[15:4]),
    .DB(128'b0),
    .QB(mem_insn_dat)
);

reg[1:0] insn_sel;
always @(posedge sys_clk)
begin
    insn_sel <= insn_addr[3:2];
end

always @(*)
begin
    case(insn_sel)
    2'b00: insn_data <= mem_insn_dat[31:0];
    2'b01: insn_data <= mem_insn_dat[63:32];
    2'b10: insn_data <= mem_insn_dat[95:64];
    2'b11: insn_data <= mem_insn_dat[127:96];
    endcase
end

endmodule
