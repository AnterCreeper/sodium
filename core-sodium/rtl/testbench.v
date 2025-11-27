`include "defines.v"

`define HALF_CYC 2.5
`define QUA_CYC 1.25
`define CYC	5

module dll(
	input enable,
	input clkin,
	output reg clkout
);
always @(*)
begin
#`QUA_CYC clkout <= enable ? clkin : 0;
end
endmodule

module testbench();

reg 	  clk;
reg 	  rst;
reg[31:0] irq;

wire 	  ram_cs;
wire 	  ram_clk;
wire 	  ram_rwds;
wire[7:0] ram_adq;

system testbench(
	.clk	 (clk),
	.rst	 (rst),
	.irq	 (irq),
	.ram_cs	 (ram_cs),
	.ram_clk (ram_clk),
	.ram_adq (ram_adq),
	.ram_rwds(ram_rwds)
);

always #`HALF_CYC clk = !clk;

initial
begin
	clk = 0;
	rst = 1;
	irq = 0;
	#250 rst = 0;
	#`HALF_CYC;
	#125000;
	irq = 1;
end

W958D8NBYA mem(
	.adq(ram_adq),
	.clk(ram_clk),
	.clk_n(1'b0),
	.csb(ram_cs),		
	.rwds(ram_rwds),
	.resetb(~rst),
	.VSS(1'b0),
	.VCC(1'b1)
); 

endmodule
