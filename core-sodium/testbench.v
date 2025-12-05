`include "defines.v"

module dll(
	input enable,
	input clkin,
	output reg clkout
);
always @(*)
begin
#`SIM_QUAT_CYC clkout <= enable ? clkin : 0;
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

always #`SIM_HALF_CYC clk = !clk;

initial
begin
	clk = 0;
	rst = 1;
	irq = 0;
	#`SIM_RELEASE rst = 0;
	#`SIM_HALF_CYC;
end

W958D8NBYA hyperram(
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
