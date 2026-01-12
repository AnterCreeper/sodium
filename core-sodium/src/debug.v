`include "defines.v"

module debug_core(
    input   clk,
    input   rst,
//IO
    output      fifo_tx_vld, //valid
    output[7:0] fifo_tx_dat, //data
    input       fifo_tx_rdy, //ready
    input       fifo_rx_vld, //valid
    input[7:0]  fifo_rx_dat, //data
    output      fifo_rx_rdy, //ready

//Bus Mgmt Path
    input 		 mgmt_req,
	input[31:0]  mgmt_adr,
	output reg	 mgmt_ack,
	input        mgmt_rwn,
	input[1:0]   mgmt_wen,
	input[31:0]  mgmt_txd,
	output reg	 mgmt_rxe,
	output[31:0] mgmt_rxd
);

wire request;
wire finish;

reg busy, issue;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        issue <= 0;
        busy  <= 0;
    end else
    begin
        issue <= !busy && mgmt_req;
        busy  <= !finish && (request || busy);
    end
end

reg        host_rwn;
reg[15:0]  host_txd;
reg[15:0]  host_rxd;
always @(posedge clk)
begin
    if(request)
    begin
        host_rwn <= mgmt_rwn;
        host_txd <= mgmt_txd;
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst) mgmt_ack <= 0;
    else    mgmt_ack <= request;
end
always @(posedge clk or posedge rst)
begin
    if(rst) mgmt_rxe <= 0;
    else    mgmt_rxe <= finish && host_rwn;
end
assign mgmt_rxd = mgmt_rxe ? host_rxd : 0;

reg valid;
always @(posedge clk)
begin
    valid <= (mgmt_adr[15:0] & `MASK_DBG) == `ADDR_DBG;
end

assign request = issue && valid;

//request, finish, busy, host_rwn, host_txd, host_rxd
assign fifo_rx_rdy = busy & host_rwn;
assign fifo_tx_vld = busy & !host_rwn;
assign fifo_tx_dat = host_txd[7:0];

assign finish = host_rwn ? 1'b1 : fifo_tx_vld && fifo_tx_rdy;

always @(posedge clk)
begin
    host_rxd <= {{8{fifo_rx_vld}}, fifo_rx_dat};
end

//Sim Debug Log Output
`ifdef DEBUG
always @(posedge clk)
begin
    if(finish && !mgmt_rwn)
        $write("%c", mgmt_txd[7:0]);
    //TODO scanf
end
`endif

endmodule
