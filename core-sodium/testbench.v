`include "defines.v"

module testbench();

reg 	  clk;
reg 	  rst;

wire 	  dram_cs;
wire 	  dram_clk;
wire[7:0] dram_adq;
wire 	  dram_rwds;

wire	  rgmii_mdc;
wire	  rgmii_mdio;

pullup(rgmii_mdio);

wire	  uart_tx;
wire	  uart_rx;

assign uart_rx = 1'b1;

system testbench(
	.ref_clk 	(clk),
	.ext_rst 	(rst),
	.uart_tx	(uart_tx),
	.uart_rx	(uart_rx)
/*
	.dram_cs	(dram_cs),
	.dram_clk   (dram_clk),
	.dram_adq   (dram_adq),
	.dram_rwds  (dram_rwds),

	.rgmii_mdc	(rgmii_mdc),
	.rgmii_mdio	(rgmii_mdio)
*/
);

always #`SIM_HALF_CYC clk = !clk;

initial
begin
	clk = 0;
	rst = 1;
	#`SIM_RELEASE rst = 0;
	#`SIM_HALF_CYC;
end

W958D8NBYA hyperram(
	.adq(dram_adq),
	.clk(dram_clk),
	.clk_n(1'b0),
	.csb(dram_cs),
	.rwds(dram_rwds),
	.resetb(~rst),
	.VSS(1'b0),
	.VCC(1'b1)
); 

endmodule
