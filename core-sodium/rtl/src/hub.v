`include "defines.v"

module ram_hub(
	input clk,
	input rst,
//TO PHY
	input phy_fin,
	output reg phy_req,
	output phy_cfg,
	output phy_rwn,
	//data path
	output[15:0] phy_txc,
	input phy_txc_ack,
	output[1:0] phy_txm,
	output[15:0] phy_txd,
	input phy_txd_ack,
	input[15:0] phy_rxd,
	input phy_rxd_vld,

//FROM Host(Memory RS)
	input host_req,
	input host_rwn,
	input host_burst,
	input[31:0] host_addr,
	output reg host_ack,
	//bypass
	input[1:0] host_txm,
	input[15:0] host_txd,
	output host_txd_ack,
	//bypass
	output reg[15:0] host_rxd,
	output reg host_rxd_vld,

//FROM Mgmt(Config RS)
	input mgmt_req,
	input mgmt_rwn,
	input[31:0] mgmt_adr,
	input[15:0] mgmt_txd,
	output reg mgmt_ack,
	output reg[15:0] mgmt_rxd,
	output reg mgmt_rxe,

	input hub_disable
);

reg bus_arb; //1 for mgmt; 0 for host;

wire       valid = ((mgmt_adr & `MASK_MC) == `ADDR_MC) && mgmt_req;
wire[31:0] addr  = {7'b0, mgmt_adr[3], 1'b0, mgmt_adr[2], 10'b0, mgmt_adr[1], 10'b0, mgmt_adr[0]}; //[31:25], 24, [23:23], 22, [21:12], 11, [10:1], 0

wire mgmt_shift, host_shift;
assign mgmt_shift = phy_txc_ack && bus_arb;
assign host_shift = phy_txc_ack && !bus_arb;

wire[63:0] mgmt_cmd_new, host_cmd_new;
assign mgmt_cmd_new = {mgmt_rwn, 1'b1, 1'b1,       addr[31:3],      13'h0, addr[2:0],   mgmt_txd};
assign host_cmd_new = {host_rwn, 1'b0, host_burst, host_addr[31:3], 13'h0, host_addr[2:0], 16'h0};

reg mgmt_act;
always @(posedge clk or posedge rst)
begin
	if(rst) mgmt_act <= 0;
	else mgmt_act <= mgmt_ack ? 0 : valid;
end

//Reserve Station MGMT
wire mgmt_clr;
reg mgmt_vld;
reg mgmt_type;
reg[63:0] mgmt_cmd;
always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		mgmt_vld <= 0;
		mgmt_ack <= 0;
	end else
	begin
		mgmt_vld  <= mgmt_act || (mgmt_vld && !mgmt_clr);
		mgmt_ack  <= mgmt_act && (mgmt_clr || !mgmt_vld);
		mgmt_type <= mgmt_act && (mgmt_clr || !mgmt_vld) ? mgmt_rwn : mgmt_type;
		mgmt_cmd  <= mgmt_act && (mgmt_clr || !mgmt_vld) ? mgmt_cmd_new : (mgmt_shift ? {mgmt_cmd[47:0], 16'h0} : mgmt_cmd); //TODO
	end
end
//Reserve Station Host
wire host_clr;
reg host_vld;
reg host_type;
reg[63:0] host_cmd;
always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		host_vld  <= 0;
		host_ack  <= 0;
	end else
	begin
		host_vld  <= host_req || (host_vld && !host_clr);
		host_ack  <= host_req && (host_clr || !host_vld);
		host_type <= host_req && (host_clr || !host_vld) ? host_rwn : host_type;
		host_cmd  <= host_req && (host_clr || !host_vld) ? host_cmd_new : (host_shift ? {host_cmd[47:0], 16'h0} : host_cmd); //TODO
	end
end

initial
begin
	bus_arb <= 1;
end

//Bus arbitration
assign phy_cfg = bus_arb;
assign phy_rwn = bus_arb ? mgmt_type : host_type;
assign phy_txm = host_txm;
assign phy_txd = host_txd;
assign phy_txc = bus_arb ? mgmt_cmd[63:48] : host_cmd[63:48];
assign mgmt_clr = bus_arb && phy_fin;
assign host_clr = !bus_arb && phy_fin;
assign host_txd_ack = phy_txd_ack;

always @(posedge clk)
begin
	mgmt_rxe 	 <=  bus_arb && phy_rxd_vld;
	mgmt_rxd 	 <=  bus_arb && phy_rxd_vld ? phy_rxd : 16'h0;
	host_rxd_vld <= !bus_arb && phy_rxd_vld;
	host_rxd 	 <= !bus_arb && phy_rxd_vld ? phy_rxd : host_rxd;
end

wire	bus_arb_new = bus_arb ? !host_vld : mgmt_vld; //1 for mgmt; 0 for host; round robin

reg 	mem_rst;
wire 	host_dis = (phy_fin && hub_disable) || mem_rst;
always @(posedge clk or posedge rst)
begin
	if(rst) mem_rst <= 1;
	else mem_rst <= phy_fin && hub_disable ? 1 : mem_rst && hub_disable;
end

always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		phy_req <= 0;
	end else
	begin
		phy_req <= mgmt_vld || (!host_dis && host_vld);
		bus_arb <= phy_fin || (!phy_req && (mgmt_vld || host_vld)) ? host_dis || bus_arb_new : bus_arb; //TODO
	end
end

endmodule
