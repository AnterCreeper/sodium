`timescale 1ns/1ps

module ram_phy(
	input clk,
	input rst,

//PIN CTRL
	output 		ram_cs,
	output reg  ram_cke,
//TX
	output reg 			ram_tx_oe,
	output reg[15:0] 	ram_tx_dat,
	output reg 			ram_rwds_oe,
	input 				ram_rwds_in,	//Sample Additional Delay
	output reg[1:0]  	ram_rwds_out,	//Write Byte Mask
//RX
	output reg 	ram_rx_en,
	input 		ram_rx_clk,
	input[7:0] 	ram_rx_dat,

//HCI CMD
	input 	req,
	input 	cfg,
	input 	r_wn, //1: read; 0: write
	output 	fin,

//HCI DAT
	//to CMD FIFO OUT
	input[15:0] tx_cmd,
	output 		tx_cmd_ack,

	//to DAT FIFO OUT
	input[1:0] 	tx_mask,
	input[15:0] tx_dat,
	output 		tx_dat_ack,
	
	//to DAT FIFO IN
	output reg[15:0] rx_dat,
	output reg 		 rx_vld,
	
//HCI CTL
	input[15:0] cr0,
	input[15:0] cr1,
	input 		wake_n
);

wire crw;
assign crw = cfg && !r_wn;

//CR VAR
wire[1:0] csh_dly = cr0[1:0];
wire[3:0] rwr_dly = cr0[5:2];
wire[9:0] tot_cnt = cfg ? 0 : cr0[15:6];
wire[7:0] cmd_dly0 = cr1[7:0];
wire[7:0] cmd_dly1 = cr1[15:8];

reg idle, start;
reg tx_fin;
reg rx_fin;
assign fin = r_wn ? rx_fin : tx_fin;

//COUNTER
reg[9:0] cnt; //clock counter
always @(posedge clk)
begin
	start <= cnt == rwr_dly;
end
always @(posedge clk or posedge rst)
begin
	if(rst) cnt <= 0;
	else if(cnt == 10'h3ff) cnt <= 10'h3ff;
	else cnt <= fin || (idle && start) || !req ? 0 : cnt + 1;
end

//SYS CTRL
reg stop, cs_n;
assign ram_cs = cs_n && wake_n;
always @(posedge clk or posedge rst) //ram_cs pin ctrl
begin
	if(rst) cs_n <= 1;
	else
	begin
		stop <= fin;
		if(stop) cs_n <= 1;
		else if(req && cnt[1:0] == csh_dly) cs_n <= 0;
	end
end
always @(posedge clk or posedge rst) //idle ctrl
begin
	if(rst) idle <= 1;
	else
	begin
		if(tx_fin) idle <= 1;
		else if(req && start) idle <= 0;
	end
end
always @(negedge clk or posedge rst) //ram_clk gate ctrl
begin
	if(rst) ram_cke <= 0;
	else ram_cke <= !idle;
end

reg extend;
reg cmd_vld, dat_vld;
always @(posedge clk or posedge rst)
begin
	if(rst) extend <= 0;
	else extend <= ram_tx_oe && cmd_vld ? ram_rwds_in : extend;
end

reg[7:0] cmd_dly;
reg[9:0] fin_dly;
always @(posedge clk)
begin
	cmd_dly <= extend ? cmd_dly1 : cmd_dly0;
	fin_dly <= tot_cnt + cmd_dly;
end

//TX Engine
always @(posedge clk or posedge rst)
begin
	if(rst)	tx_fin <= 0;
	else tx_fin <= idle ? 0 : (crw ? cnt == 2 : cnt == fin_dly);
end

always @(posedge clk)
begin
	cmd_vld <= start  && idle ? 1 : (cnt >= 2 + crw ? 0 : cmd_vld);
	dat_vld <= tx_fin || idle ? 0 : (cnt >= cmd_dly ? 1 : dat_vld);
end

wire tx_en;
assign tx_en = (cmd_vld || (dat_vld && !r_wn)) && !idle;

assign tx_cmd_ack = cmd_vld && !idle;
assign tx_dat_ack = dat_vld && !r_wn;

always @(posedge clk)
begin
	if(!idle)
	begin
		ram_tx_dat <= dat_vld ? tx_dat : tx_cmd;
		ram_rwds_out <= dat_vld ? tx_mask : ram_rwds_out;
	end
end
always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		ram_tx_oe <= 0;
		ram_rwds_oe <= 0;
	end else
	begin
		ram_tx_oe <= tx_en;
		ram_rwds_oe <= dat_vld && !r_wn;
	end
end

//RX Engine
wire rx_en;
assign rx_en = dat_vld && r_wn;
always @(posedge clk or posedge rst)
begin
	if(rst) ram_rx_en <= 0;
	else ram_rx_en <= rx_en ? 1 : (rx_fin ? 0 : ram_rx_en);
end

reg ram_rx_rst, ram_rx_run;
reg[1:0] ram_rx_icnt;
reg[9:0] ram_rx_ocnt;

reg[15:0] ram_rx_buf[3:0];

//FIFO input
always @(negedge ram_rx_clk or negedge ram_rx_en)
begin
	if(!ram_rx_en) ram_rx_icnt <= 0;
	else ram_rx_icnt <= ram_rx_icnt + 1;
end
always @(posedge ram_rx_clk or negedge ram_rx_en)
begin
	if(!ram_rx_en) ram_rx_rst <= 1;
	else ram_rx_rst <= 0;
end
always @(negedge ram_rx_clk)
begin
	ram_rx_buf[ram_rx_icnt][7:0] <= ram_rx_dat;
end
always @(posedge ram_rx_clk)
begin
	ram_rx_buf[ram_rx_icnt][15:8] <= ram_rx_dat;
end
//Async Boundaries
reg sync;
always @(posedge clk or posedge ram_rx_rst) begin
    if (ram_rx_rst) begin
        sync <= 0;
		ram_rx_run <= 0;
    end else
    begin
        sync <= 1;
        ram_rx_run <= sync;
    end
end
//FIFO output
always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		rx_vld <= 0;
		ram_rx_ocnt <= 0;
		rx_fin <= 0;
	end else
	begin
		rx_dat <= ram_rx_buf[ram_rx_ocnt[1:0]];
		rx_vld <= ram_rx_run && !rx_fin;
		ram_rx_ocnt <= ram_rx_run && !rx_fin ? ram_rx_ocnt + 1 : 0;
		rx_fin <= ram_rx_run ? ram_rx_ocnt == tot_cnt : 0;
	end
end
endmodule
