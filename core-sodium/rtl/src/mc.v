`include "defines.v"

module mp_mc(
	input clk,
	input rst,
//HOST
	input 			host_req,
	input 			host_rwn,
	input 			host_burst,
	input[31:0] 	host_addr,
	output 			host_ack,
	//bypass
	input[1:0] 		host_txm,
	input[15:0] 	host_txd,
	output 			host_txd_ack,
	//bypass
	output[15:0] 	host_rxd,
	output 			host_rxd_vld,
//MGMT
    input 			mgmt_req,
	input[31:0] 	mgmt_adr,
	output 			mgmt_ack,
	input          	mgmt_rwn,
	input[1:0]     	mgmt_wen,
	input[31:0] 	mgmt_txd,
	output 			mgmt_rxe,
	output[31:0] 	mgmt_rxd,
//CTRL
	input[15:0]		cr0,
	input[15:0]		cr1,
	input[15:0]		cr2,
//IO
	output 			ram_cs,
	output 			ram_clk,
	inout[7:0] 		ram_adq,
	inout 			ram_rwds
);

wire 		ram_cke;
wire[7:0] 	ram_adq_ddr;

wire 		ram_tx_oe;
wire[15:0] 	ram_tx_dat;

wire 		ram_rx_en;
wire 		ram_rx_clk;
reg[15:0] 	ram_rx_dat;

wire 		ram_rwds_oe;
wire 		ram_rwds_ddr;
wire[1:0] 	ram_rwds_out;

//Physical
dll dll_ckout(
	.enable(ram_cke),
	.clkin(clk),
	.clkout(ram_clk)
);
dll dll_ckin(
	.enable(ram_rx_en),
	.clkin(ram_rwds),
	.clkout(ram_rx_clk)
);

assign ram_rwds 	= ram_rwds_oe ? ram_rwds_ddr : 1'bz;
assign ram_rwds_ddr = clk ? ram_rwds_out[1]  : ram_rwds_out[0];
assign ram_adq 		= ram_tx_oe   ? ram_adq_ddr  : 8'bz;
assign ram_adq_ddr	= clk ? ram_tx_dat[15:8] : ram_tx_dat[7:0];

//Controller
wire 		phy_req;
wire 		phy_fin;
wire 		phy_cfg;
wire 		phy_rwn;
wire[15:0] 	phy_txc;
wire 		phy_txc_ack;
wire[1:0] 	phy_txm;
wire[15:0] 	phy_txd;
wire 		phy_txd_ack;
wire[15:0] 	phy_rxd;
wire 		phy_rxd_vld;

wire		phy_wake_n;
wire 		hub_disable;

assign		phy_wake_n 	= !cr2[1];
assign		hub_disable	= !cr2[0];

assign 		mgmt_rxd[31:16] = 0;

ram_hub hub(
	.clk(clk),
	.rst(rst),

	//TO PHY
	.phy_req	 (phy_req),
	.phy_fin	 (phy_fin),
	.phy_cfg	 (phy_cfg),
	.phy_rwn	 (phy_rwn),
	.phy_txc	 (phy_txc),
	.phy_txc_ack (phy_txc_ack),
	.phy_txm	 (phy_txm),
	.phy_txd	 (phy_txd),
	.phy_txd_ack (phy_txd_ack),
	.phy_rxd	 (phy_rxd),
	.phy_rxd_vld (phy_rxd_vld),
	
	//FROM Host
	.host_req	 (host_req),
	.host_rwn	 (host_rwn),
	.host_burst	 (host_burst),
	.host_addr	 (host_addr),
	.host_ack	 (host_ack),
	.host_txm	 (host_txm),
	.host_txd	 (host_txd),
	.host_txd_ack(host_txd_ack),
	.host_rxd	 (host_rxd),
	.host_rxd_vld(host_rxd_vld),
	
	//FROM Mgmt
	.mgmt_req	 (mgmt_req),
	.mgmt_rwn	 (mgmt_rwn),
	.mgmt_adr	 (mgmt_adr),
	.mgmt_txd	 (mgmt_txd[15:0]),
	.mgmt_ack	 (mgmt_ack),
	.mgmt_rxd	 (mgmt_rxd[15:0]),
	.mgmt_rxe	 (mgmt_rxe),

	.hub_disable (hub_disable)
);

ram_phy phy(
	.clk(clk),
	.rst(rst),

	//IO
	.ram_cs		 (ram_cs),
	.ram_cke	 (ram_cke),
	.ram_tx_oe	 (ram_tx_oe),
	.ram_tx_dat	 (ram_tx_dat),
	.ram_rwds_oe (ram_rwds_oe),
	.ram_rwds_in (ram_rwds),
	.ram_rwds_out(ram_rwds_out),
	.ram_rx_en	 (ram_rx_en),
	.ram_rx_clk	 (ram_rx_clk),
	.ram_rx_dat	 (ram_adq),

	//FROM HUB
	.req		 (phy_req),
	.fin		 (phy_fin),
	.cfg		 (phy_cfg),
	.r_wn		 (phy_rwn),
	.tx_cmd		 (phy_txc),
	.tx_cmd_ack	 (phy_txc_ack),
	.tx_mask	 (phy_txm),
	.tx_dat		 (phy_txd),
	.tx_dat_ack	 (phy_txd_ack),
	.rx_dat		 (phy_rxd),
	.rx_vld		 (phy_rxd_vld),

	//SYS CTRL
	.cr0		 (cr0),
	.cr1		 (cr1),
	.wake_n		 (phy_wake_n)
);
	
endmodule
