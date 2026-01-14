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

gowin_dpb gw_ram(
    .douta(QA), //output [127:0] douta
    .doutb(QB), //output [127:0] doutb
    .clka(CLK), //input clka
    .cea(!CENA), //input cea
    .wrea(!WENA), //input wrea
    .clkb(CLK), //input clkb
    .ceb(!CENB), //input ceb
    .wreb(!WENB), //input wreb
    .ada(AA), //input [10:0] ada
    .dina(DA), //input [127:0] dina
    .adb(AB), //input [10:0] adb
    .dinb(DB), //input [127:0] dinb
    .reseta(1'b0), //input reseta
    .resetb(1'b0), //input resetb
    .ocea(1'b1), //input ocea
    .oceb(1'b1) //input oceb
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
    output usb_clk,
    output sys_rst
);

wire locked;
gowin_pll gw_clk(
    .clkin(ref_clk), //input  clkin
    .clkout0(sys_clk), //output  clkout0, 40MHz
    .clkout1(usb_clk), //output  clkout1, 60MHz
    .lock(locked), //output  lock
    .mdclk(ref_clk) //input  mdclk
);
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

//port A for write, port B for read
gowin_sdpb gw_ram(
    .dout(QA), //output [6:0] dout
    .clka(CLK), //input clka
    .cea(!CENB), //input cea
    .clkb(CLK), //input clkb
    .ceb(!CENA), //input ceb
    .ada(AB), //input [4:0] ada
    .din(DB), //input [6:0] din
    .adb(AA), //input [4:0] adb
    .reset(1'b0), //input reset
    .oce(1'b1) //input oce
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

gowin_sp gw_ram(
    .dout(Q), //output [127:0] dout
    .clk(CLK), //input clk
    .ce(!CEN), //input ce
    .ad(A), //input [4:0] ad
    .din(D), //input [127:0] din
    .byte_en(~WEN), //input [15:0] byte_en
    .reset(1'b0), //input reset
    .oce(1'b1) //input oce
);

endmodule
