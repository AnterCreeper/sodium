`include "defines.v"

`define MDIO_CLK_CYC    10  //50MHz to 2.5MHz
`define MDIO_HOLD_CYC   5

module mdio_core(
    input   clk,
    input   rst,
//IO
    output reg   mdio_clk,
    output reg   mdio_txe,
    output reg   mdio_txd,
    input        mdio_rxd,

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

wire[4:0]  mdio_phy = {2'b0, mgmt_adr[7:5]};
wire[4:0]  mdio_reg = mgmt_adr[4:0];
wire[15:0] mdio_cmd = {2'b01, mgmt_rwn, !mgmt_rwn, mdio_phy, mdio_reg, 2'b10};

//uOPs
reg        host_rwn;
wire       host_cse;
reg[15:0]  host_cmd;
wire       host_dse;
reg[15:0]  host_txd;
reg[15:0]  host_rxd;
reg[7:0]   host_cnt;
reg[7:0]   host_div;
always @(posedge clk)
begin
    if(request)
    begin
        host_rwn <= mgmt_rwn;
        host_cmd <= mdio_cmd;
        host_txd <= {16'b0, mgmt_txd};
        host_cnt <= `MDIO_CLK_CYC-1;
        host_div <= `MDIO_CLK_CYC;
    end else
    begin
        if(host_cse) host_cmd <= {host_cmd[14:0], 1'b0};
        if(host_dse) host_txd <= {host_txd[14:0], 1'b0};
        if(busy) host_cnt <= host_cnt == host_div ? 0 : host_cnt + 1;
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

reg mdio_stp;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mdio_stp <= 0;
        mdio_clk <= 1;
    end else
    begin
        mdio_stp <= busy && host_cnt == host_div;
        mdio_clk <= busy && host_cnt == host_div ? ~mdio_clk : mdio_clk;
    end
end

`define FSM_IDLE    3'b001
`define FSM_ADDR    3'b010  //2+2+5+5+2 = 16bit
`define FSM_DATA    3'b100  //16bit

reg[2:0] fsm;
reg[5:0] cnt;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        cnt <= 0;
        fsm <= `FSM_IDLE;
    end else
    if(mdio_stp)
    begin
        cnt <= cnt + 1;
        case(fsm)
        `FSM_IDLE: fsm <= cnt == 63 ? `FSM_ADDR : `FSM_IDLE;
        `FSM_ADDR: fsm <= cnt == 31 ? `FSM_DATA : `FSM_ADDR;
        `FSM_DATA: fsm <= cnt == 63 ? `FSM_IDLE : `FSM_DATA;
        endcase
    end
end

reg last, valid;
always @(posedge clk)
begin
    last  <= (mdio_stp && fsm == `FSM_DATA && cnt == 63) || (busy && last);
    valid <= (mgmt_adr[15:0] & `MASK_MDC) == `ADDR_MDC;
end

assign request = issue && valid;
assign finish = last && host_cnt == `MDIO_HOLD_CYC;

wire mdio_ctl = cnt[0];
always @(posedge clk)
begin
    if(mdio_stp && mdio_ctl)
        host_rxd <= {host_rxd[14:0], mdio_rxd};
    if(mdio_stp && !mdio_ctl)
    case(fsm)
    `FSM_IDLE: mdio_txd <= 1'b1;
    `FSM_ADDR: mdio_txd <= host_cmd[15];
    `FSM_DATA: mdio_txd <= host_txd[15];
    endcase
end

assign host_cse = mdio_stp && mdio_ctl && fsm == `FSM_ADDR;
assign host_dse = mdio_stp && mdio_ctl && fsm == `FSM_DATA;

reg mdio_start, mdio_stop;
always @(posedge clk)
begin
    mdio_start <= mdio_stp && fsm == `FSM_IDLE && cnt == 0;
    mdio_stop  <= mdio_stp && fsm == `FSM_ADDR && cnt == 28;
end

always @(posedge clk or posedge rst)
begin
    if(rst)   mdio_txe <= 1'b0;
    else
    if(!busy) mdio_txe <= 1'b0;
    else      mdio_txe <= (mdio_txe && !mdio_stop) || mdio_start;
end

endmodule
