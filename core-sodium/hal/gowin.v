`include "defines.v"

//System On-Chip-RAM(OCM) Macro
module sys_sram(
    input           CLK,
    input           CENA,
    input           WENA,
    input[11:0]     AA,
    input[127:0]    DA,
    output[127:0]   QA,
    input           CENB,
    input           WENB,
    input[11:0]     AB,
    input[127:0]    DB,
    output[127:0]   QB
);

endmodule

//Delay Lock Looped and Clock Gating
//delay clkin to clkout for a quarter cycle of refclk
module sys_delay(
	input enable,
	input refclk,
	input clkin,
	output clkout
);
assign clkout = enable ? clkin : 0;
endmodule

//System Clock Generator
module sys_clkgen(
    input ref_clk,
    input ext_rst,
    output sys_clk,
    output sys_rst
);

wire locked;
assign sys_rst = !locked;

endmodule

//Data Cache Tags RAM
module dcache_tag(
    input         CLK,
    input         CENA,
    input[4:0]    AA,
    output[6:0]   QA,
    input         CENB,
    input[4:0]    AB,
    input[6:0]    DB
);

endmodule

//Data Cache Data RAM
module dcache_mem(
    input         CLK,
    input         CEN,
    input[15:0]   WEN,
    input[4:0]    A,
    input[127:0]  D,
    output[127:0] Q
);

endmodule
